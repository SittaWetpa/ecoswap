/**
 * WBS 10.6 — Trade Record Write + Impact Counters (helper stub).
 *
 * The real implementation of this helper is the deliverable of WBS 10.6 —
 * see `docs/EcoSwap_WBS_Dictionary.md` § 10.6 for the pseudocode that lays
 * out the per-user attribution math (CO₂ for what you received, waste for
 * what you gave) and the four Firestore writes the transaction must perform:
 *
 *   1. set /trades/{tradeId} with the structured `impact` object
 *   2. update both /items/ to `status: 'traded'`
 *   3. increment both /users/ counter triples (tradesCount, totalCo2Saved,
 *      totalWasteDiverted)
 *
 * This module is referenced by WBS 10.2's `validateQRToken`, which runs the
 * single-use check, the match read, and the trade write inside ONE
 * `db.runTransaction` block. The transaction handle is passed in so all
 * writes commit atomically with the match's status flip to 'completed'.
 *
 * STATUS: stub. This file exists so 10.2 can import a typed handle today.
 * The function throws `HttpsError('unimplemented', ...)` when invoked, which
 * propagates through the runTransaction back to the caller. WBS 10.2's
 * five error-path unit tests all throw before reaching this helper and so
 * are unaffected by the stub. The happy-path integration test in 10.2's
 * Testing section depends on WBS 10.6 landing; that test is marked
 * `test.skip` with a TODO referencing this stub.
 *
 * When WBS 10.6 implements this for real, it MUST:
 *   - Accept the same signature (tx, match, matchId, tokenHash) — 10.2 already
 *     calls it that way.
 *   - Return the newly-allocated tradeId string.
 *   - Use FieldValue.serverTimestamp() for completedAt.
 *   - Use FieldValue.increment() for the six counter writes.
 *   - Read CO2_INTENSITY and TYPICAL_WEIGHT from
 *     `functions/src/constants/impact.ts` (kept in sync with the Dart copy).
 */

import { HttpsError } from "firebase-functions/https";
import type { Transaction } from "firebase-admin/firestore";
import type { MatchDoc } from "./types";

/**
 * Write a /trades/ doc, flip both items to status='traded', and increment
 * counters on both participants. Called from inside the runTransaction that
 * starts in WBS 10.2's `validateQRToken`.
 *
 * @param _tx        Firestore transaction handle from `db.runTransaction`.
 * @param _match     The match document data (already read by 10.2 inside tx).
 * @param _matchId   The match document id.
 * @param _tokenHash SHA-256 of the JWT, written to the trade doc's
 *                   `jwtTokenHash` field as the single-use marker.
 * @returns          The newly-allocated /trades/{tradeId} document id.
 */
export async function writeTradeAndImpact(
  _tx: Transaction,
  _match: MatchDoc,
  _matchId: string,
  _tokenHash: string,
): Promise<string> {
  throw new HttpsError(
    "unimplemented",
    "writeTradeAndImpact stub — real implementation lands in WBS 10.6",
  );
}
