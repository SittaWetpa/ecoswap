/**
 * WBS 8.5 — Hard-Cancel Pending Swipes When Item Traded.
 *
 * Firestore-triggered Cloud Function: when an /items/{itemId} document
 * flips from `status: 'active'` to `status: 'traded'` (a transition that
 * only the WBS 10.6 transaction performs), sweep the side-effects:
 *
 *   1. Cancel every OTHER /matches/ doc that referenced this item — i.e.
 *      matches where `userAWantsItemId == itemId` OR `userBWantsItemId
 *      == itemId` AND `status == 'active'`, EXCEPT the match that caused
 *      the trade.
 *   2. Notify the OTHER party of each cancelled match (a row in
 *      /users/{uid}/notifications/) so their UI can offer a "find similar"
 *      affordance.
 *   3. Delete every pending right-swipe whose `desiredItemId` is this item.
 *      Left-swipes are not touched; they represent intentional rejections
 *      and have no follow-on UI impact.
 *
 * Per the locked decisions in CLAUDE.md and WBS 3.6:
 *   - This function MUST NOT write /trades/ or any /users/ impact counter
 *     fields (`tradesCount`, `totalCo2Saved`, `totalWasteDiverted`). Those
 *     are owned exclusively by WBS 10.6's transaction.
 *   - The notification payload stays minimal: `type: 'item_unavailable'`,
 *     `itemId`, `similarSearchQuery`, `createdAt`. No GPS/km/age/etc.
 *
 * Guard against re-fire: the `before/after` status check ensures this only
 * runs on the specific active->traded transition. Any other update to the
 * item doc (e.g. a later edit, an admin re-flag) is a no-op.
 *
 * The "completing match" — the one whose successful QR scan caused the
 * trade — must be excluded from cancellation. We find it by querying
 * /trades/ for the doc whose `itemsExchanged.fromA` or
 * `itemsExchanged.fromB` equals this itemId, and collect its `matchId`(s)
 * into a skip-set.
 */

import { onDocumentUpdated } from "firebase-functions/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { ItemDoc, MatchDoc, TradeDoc } from "./types";

// Initialize the Admin SDK exactly once across the process. Tests that call
// `initializeApp` themselves with emulator settings are safe — getApps()
// guards against double-init.
if (getApps().length === 0) {
  initializeApp();
}

/**
 * Trigger handler exported as a plain function so unit tests can drive it
 * directly with synthetic before/after payloads, without standing up the
 * Cloud Functions framework. Mirrors the `handleSwipeCreated` pattern in
 * WBS 8.3.
 *
 * @param before  The item doc data BEFORE the update.
 * @param after   The item doc data AFTER the update.
 * @param itemId  The id of the item being updated.
 */
export async function handleItemTraded(
  before: ItemDoc | undefined,
  after: ItemDoc | undefined,
  itemId: string,
): Promise<void> {
  // Guard: only run on the active -> traded transition. Without this guard
  // the function would re-fire on EVERY subsequent update to the doc and
  // duplicate the cancellations/notifications.
  if (before?.status !== "active") return;
  if (after?.status !== "traded") return;

  const db = getFirestore();

  // -------------------------------------------------------------------------
  // Identify the "completing match" so we can skip cancelling it (and skip
  // notifying its parties — the trade succeeded for them, by definition).
  //
  // The trade doc that caused this status flip references the item via
  // `itemsExchanged.fromA` or `itemsExchanged.fromB`. Query both fields.
  // -------------------------------------------------------------------------
  const [completingTradesA, completingTradesB] = await Promise.all([
    db.collection("trades").where("itemsExchanged.fromA", "==", itemId).get(),
    db.collection("trades").where("itemsExchanged.fromB", "==", itemId).get(),
  ]);
  const completingMatchIds = new Set<string>([
    ...completingTradesA.docs.map((d) => (d.data() as TradeDoc).matchId),
    ...completingTradesB.docs.map((d) => (d.data() as TradeDoc).matchId),
  ]);

  // -------------------------------------------------------------------------
  // Find other pending matches that referenced this item, and pending
  // right-swipes targeting this item. All three queries run in parallel.
  // -------------------------------------------------------------------------
  const [matchesA, matchesB, pendingSwipes] = await Promise.all([
    db
      .collection("matches")
      .where("userAWantsItemId", "==", itemId)
      .where("status", "==", "active")
      .get(),
    db
      .collection("matches")
      .where("userBWantsItemId", "==", itemId)
      .where("status", "==", "active")
      .get(),
    db
      .collection("swipes")
      .where("desiredItemId", "==", itemId)
      .where("direction", "==", "right")
      .get(),
  ]);

  // The same match doc could appear in BOTH matchesA and matchesB if both
  // wanted-item fields happen to point at this item (degenerate but
  // theoretically possible: a self-swap match doc). De-dupe by doc id.
  const matchDocsById = new Map<
    string,
    FirebaseFirestore.QueryDocumentSnapshot
  >();
  for (const doc of [...matchesA.docs, ...matchesB.docs]) {
    matchDocsById.set(doc.id, doc);
  }

  // The traded item's name powers the "find similar X" notification copy.
  // Prefer `after.name` (the freshly-updated doc) over a fresh read.
  const similarSearchQuery = after.name;

  // -------------------------------------------------------------------------
  // Batch all writes so they commit atomically. The Firestore batch limit is
  // 500 ops; a single item being traded won't realistically generate
  // anything close to that (matches and swipes are both small populations).
  // -------------------------------------------------------------------------
  const batch = db.batch();
  let writeCount = 0;

  for (const doc of matchDocsById.values()) {
    // Skip the match that the trade itself completed — its parties already
    // know about the successful swap; cancelling it would corrupt /matches/
    // (10.2 sets status='completed', we'd overwrite that to 'cancelled').
    if (completingMatchIds.has(doc.id)) continue;

    const data = doc.data() as MatchDoc;
    batch.update(doc.ref, { status: "cancelled" });
    writeCount++;

    // Notify the OTHER party — the one whose match just got invalidated by
    // somebody else trading away the item they wanted. If userAWantsItemId
    // is the traded item, then user A is the one who loses out; otherwise
    // it's user B.
    const otherUid =
      data.userAWantsItemId === itemId ? data.userAId : data.userBId;
    const notifRef = db
      .collection("users")
      .doc(otherUid)
      .collection("notifications")
      .doc();
    batch.set(notifRef, {
      type: "item_unavailable",
      itemId,
      similarSearchQuery,
      createdAt: FieldValue.serverTimestamp(),
    });
    writeCount++;
  }

  // Delete every pending right-swipe referencing this item. These users
  // never got a match (no reciprocal yet) so there's no notification owed
  // here — the item simply vanishes from their feed.
  for (const doc of pendingSwipes.docs) {
    batch.delete(doc.ref);
    writeCount++;
  }

  if (writeCount === 0) return;
  await batch.commit();
}

/**
 * Firestore trigger wrapper. Delegates to `handleItemTraded` so unit tests
 * can exercise the logic without the full Functions framework.
 */
export const onItemTraded = onDocumentUpdated(
  "items/{itemId}",
  async (event) => {
    const before = event.data?.before.data() as ItemDoc | undefined;
    const after = event.data?.after.data() as ItemDoc | undefined;
    await handleItemTraded(before, after, event.params.itemId);
  },
);
