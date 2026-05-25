/**
 * WBS 10.6 — Trade Record Write + Impact Counters.
 *
 * Real implementation of the helper called from inside WBS 10.2's
 * `validateQRToken` transaction. Performs the four Firestore writes the
 * dictionary's pseudocode specifies, all on the passed-in `tx` so they
 * commit atomically with the match status flip in the caller:
 *
 *   1. tx.set    /trades/{tradeId}  with the structured `impact` object,
 *                                   `jwtTokenHash`, `itemsExchanged`, and
 *                                   FieldValue.serverTimestamp() for
 *                                   completedAt.
 *   2. tx.update /items/{aGivesId}  → { status: 'traded' }
 *   3. tx.update /items/{bGivesId}  → { status: 'traded' }
 *   4. tx.update /users/{aId}       → tradesCount/totalCo2Saved/
 *                                     totalWasteDiverted increments
 *   5. tx.update /users/{bId}       → mirror of 4
 *
 * Per-user attribution (locked by CLAUDE.md "Impact calculation" rules and
 * by 11.1's worked example):
 *
 *   - co2Saved      = weight_of_item_RECEIVED × intensity_of_item_RECEIVED
 *   - wasteDiverted = weight_of_item_GIVEN
 *
 * `match.userAWantsItemId` is the item user A wants — i.e. the item B is
 * giving to A. So `bGives` resolves from `userAWantsItemId`, and `aGives`
 * resolves from `userBWantsItemId`. The pseudocode in the WBS entry
 * spells this out; we preserve the same variable names in the code so the
 * cross-reference holds.
 *
 * Reads happen BEFORE writes (Promise.all on two tx.get calls), which is
 * required by Firestore transaction semantics. The caller in 10.2 only
 * performs tx.get operations before invoking this helper, so the
 * reads-first ordering is preserved across the whole transaction.
 *
 * This function (together with validateQRToken in 10.2) is the ONLY writer
 * of `/trades/` documents and of the `tradesCount`, `totalCo2Saved`, and
 * `totalWasteDiverted` fields on `/users/{uid}`. Server-side only.
 */

import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";
import type { Transaction } from "firebase-admin/firestore";

import { CO2_INTENSITY, TYPICAL_WEIGHT } from "./constants/impact";
import type { ItemDoc, MatchDoc, TradeDoc } from "./types";

/**
 * Write a /trades/ doc, flip both items to status='traded', and increment
 * counters on both participants. Called from inside the runTransaction that
 * starts in WBS 10.2's `validateQRToken`.
 *
 * @param tx        Firestore transaction handle from `db.runTransaction`.
 * @param match     The match document data (already read by 10.2 inside tx).
 * @param matchId   The match document id.
 * @param tokenHash SHA-256 of the JWT, written to the trade doc's
 *                  `jwtTokenHash` field as the single-use marker.
 * @returns         The newly-allocated /trades/{tradeId} document id.
 */
export async function writeTradeAndImpact(
  tx: Transaction,
  match: MatchDoc,
  matchId: string,
  tokenHash: string,
): Promise<string> {
  const db = getFirestore();

  // ---------------------------------------------------------------------
  // READS — must precede any writes in this transaction.
  //
  // `userBWantsItemId` is the item B wants; A is giving it to B → aGives.
  // `userAWantsItemId` is the item A wants; B is giving it to A → bGives.
  // ---------------------------------------------------------------------
  const aGivesRef = db.doc(`items/${match.userBWantsItemId}`);
  const bGivesRef = db.doc(`items/${match.userAWantsItemId}`);

  const [aGivesSnap, bGivesSnap] = await Promise.all([
    tx.get(aGivesRef),
    tx.get(bGivesRef),
  ]);

  const aGives = aGivesSnap.data() as ItemDoc | undefined;
  const bGives = bGivesSnap.data() as ItemDoc | undefined;

  // If either item is missing the match is unredeemable — bail with a
  // canonical failed-precondition. This mirrors the MATCH_INVALID surface
  // from 10.2: a structurally broken match should not silently produce a
  // NaN-filled trade doc.
  if (!aGives || !bGives) {
    throw new HttpsError(
      "failed-precondition",
      "MATCH_INVALID",
    );
  }

  // ---------------------------------------------------------------------
  // IMPACT MATH (locked by WBS 10.6 pseudocode + 11.1 worked example).
  // ---------------------------------------------------------------------
  const wA = aGives.weight ?? TYPICAL_WEIGHT[aGives.category];
  const wB = bGives.weight ?? TYPICAL_WEIGHT[bGives.category];
  const iA = CO2_INTENSITY[aGives.category];
  const iB = CO2_INTENSITY[bGives.category];

  // A receives bGives → A's CO2 credit = wB * iB.  A gave aGives → A's waste = wA.
  const aCo2 = wB * iB;
  const aWaste = wA;
  // B receives aGives → B's CO2 credit = wA * iA.  B gave bGives → B's waste = wB.
  const bCo2 = wA * iA;
  const bWaste = wB;

  // ---------------------------------------------------------------------
  // WRITES — all go through `tx` so they commit atomically with the
  // caller's match-status flip.
  // ---------------------------------------------------------------------
  const tradeRef = db.collection("trades").doc();

  // Note: TradeDoc.completedAt is typed as Timestamp, but at write time we
  // use FieldValue.serverTimestamp() (a sentinel resolved by Firestore at
  // commit). The two are compatible in the Admin SDK's write API; the
  // read-time value will always be a Timestamp.
  const tradeData: Omit<TradeDoc, "completedAt"> & {
    completedAt: FirebaseFirestore.FieldValue;
  } = {
    matchId,
    completedAt: FieldValue.serverTimestamp(),
    jwtTokenHash: tokenHash,
    impact: {
      userAGains: {
        userId: match.userAId,
        co2Saved: aCo2,
        wasteDiverted: aWaste,
      },
      userBGains: {
        userId: match.userBId,
        co2Saved: bCo2,
        wasteDiverted: bWaste,
      },
    },
    itemsExchanged: {
      fromA: match.userBWantsItemId, // A's item now in B's hands
      fromB: match.userAWantsItemId, // B's item now in A's hands
    },
  };

  tx.set(tradeRef, tradeData);

  tx.update(aGivesRef, { status: "traded" });
  tx.update(bGivesRef, { status: "traded" });

  tx.update(db.doc(`users/${match.userAId}`), {
    tradesCount: FieldValue.increment(1),
    totalCo2Saved: FieldValue.increment(aCo2),
    totalWasteDiverted: FieldValue.increment(aWaste),
  });
  tx.update(db.doc(`users/${match.userBId}`), {
    tradesCount: FieldValue.increment(1),
    totalCo2Saved: FieldValue.increment(bCo2),
    totalWasteDiverted: FieldValue.increment(bWaste),
  });

  return tradeRef.id;
}
