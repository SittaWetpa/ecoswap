/**
 * WBS 8.3 — Mutual Swipe Detection.
 *
 * Firestore-triggered Cloud Function: when a new `/swipes/{swipeId}` document
 * is created with `direction: 'right'`, look for a reciprocal right-swipe
 * from the target back to the swiper. If one exists AND both swipes declare
 * items that are still `status: 'active'`, atomically create a single
 * `/matches/{matchId}` document recording both sides' declared items.
 *
 * Per the locked decisions in CLAUDE.md and the schemas in WBS 3.6:
 *   - `desiredItemId` is a single string on each /swipes/ doc (F16 single-select).
 *   - The match doc carries `participants: [userAId, userBId]` for the
 *     security-rules query that gates /matches/ reads (WBS 3.2).
 *   - `userAWantsItemId` is what user A wants (the item A's swipe pointed at,
 *     which is owned by B). `userBWantsItemId` is symmetric.
 *
 * Idempotency: the match id is the sorted-and-joined pair of uids, so two
 * concurrent trigger fires hash to the same document. The transaction reads
 * that doc first and bails if it already exists — only one match write wins.
 *
 * Defensive item-status check: if either declared item has flipped away from
 * 'active' (e.g. traded elsewhere before the reciprocal swipe), no match is
 * created. This mirrors WBS 8.5 (`onItemTraded`) which sweeps in the opposite
 * direction.
 */

import { onDocumentCreated } from "firebase-functions/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { SwipeDoc, MatchDoc } from "./types";

// Initialize the Admin SDK exactly once across the process. Importing this
// module from tests (which call `initializeApp` themselves with emulator
// settings) is safe — `getApps().length` guards against double-init.
if (getApps().length === 0) {
  initializeApp();
}

/**
 * Trigger handler exported so unit tests can call it directly with a fake
 * event payload, without going through the full Functions framework.
 */
export async function handleSwipeCreated(
  swipe: SwipeDoc | undefined,
): Promise<void> {
  if (!swipe) return;
  if (swipe.direction !== "right") return;

  const db = getFirestore();

  // Look for a reciprocal right-swipe from target back to swiper.
  const reciprocal = await db
    .collection("swipes")
    .where("swiperId", "==", swipe.targetUserId)
    .where("targetUserId", "==", swipe.swiperId)
    .where("direction", "==", "right")
    .limit(1)
    .get();
  if (reciprocal.empty) return;

  const other = reciprocal.docs[0].data() as SwipeDoc;

  // Defensive: both declared items must still be `status: 'active'`.
  // `swipe.desiredItemId` is what the new-swipe's swiper wants (owned by
  // the target); `other.desiredItemId` is what the target wants (owned by
  // the new-swipe's swiper). Both must still be available.
  const [theirsWanted, oursWanted] = await Promise.all([
    db.doc(`items/${swipe.desiredItemId}`).get(),
    db.doc(`items/${other.desiredItemId}`).get(),
  ]);
  if (theirsWanted.data()?.status !== "active") return;
  if (oursWanted.data()?.status !== "active") return;

  // Idempotent match-id: sorted pair of uids joined by underscore. Two
  // concurrent trigger invocations collapse onto the same document, and the
  // transaction's pre-read guarantees only one wins.
  const matchId = [swipe.swiperId, swipe.targetUserId].sort().join("_");
  const matchRef = db.doc(`matches/${matchId}`);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(matchRef);
    if (existing.exists) return;

    // The "swiper" of the newly-created swipe is user A in the resulting
    // match doc; that's what the WBS 8.3 pseudocode prescribes. A wanted
    // `swipe.desiredItemId`, B wanted `other.desiredItemId`.
    const matchData: MatchDoc = {
      userAId: swipe.swiperId,
      userBId: swipe.targetUserId,
      userAWantsItemId: swipe.desiredItemId,
      userBWantsItemId: other.desiredItemId,
      status: "active",
      participants: [swipe.swiperId, swipe.targetUserId],
      // FieldValue.serverTimestamp() is not a Timestamp at write time but
      // resolves to one server-side. Cast keeps the MatchDoc shape honest.
      createdAt: FieldValue.serverTimestamp() as unknown as MatchDoc["createdAt"],
      completedAt: null,
    };
    tx.set(matchRef, matchData);
  });
}

/**
 * Firestore trigger wrapper. The handler delegates to `handleSwipeCreated`
 * so unit tests can exercise the logic without standing up the Cloud
 * Functions framework.
 */
export const onSwipeCreated = onDocumentCreated(
  "swipes/{swipeId}",
  async (event) => {
    const swipe = event.data?.data() as SwipeDoc | undefined;
    await handleSwipeCreated(swipe);
  },
);
