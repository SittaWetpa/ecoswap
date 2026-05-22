/**
 * WBS 10.2 — Cloud Function: Validate Scanned JWT.
 *
 * Callable Cloud Function. Given a `token` that the scanner picked up from
 * the displayer's QR code (10.3) or pasted into the DEV-MODE fallback (10.5),
 * runs the four security checks specified in §8.3 of the planning doc:
 *
 *   1. SIGNATURE — `jwt.verify(token, JWT_SECRET)` with algorithm pinned to
 *      HS256. A forged token (wrong key) maps to error code INVALID_SIGNATURE.
 *   2. EXPIRY  — the JWT's `exp` claim must be in the future. `jwt.verify`
 *      enforces this automatically; expired tokens throw `TokenExpiredError`
 *      and map to error code EXPIRED.
 *   3. COUNTERPARTY — `payload.displayerUserId !== scannerUid`. If the
 *      scanner is the user who issued the QR (i.e. they're scanning their
 *      own phone), reject with WRONG_COUNTERPARTY. Additionally inside the
 *      transaction we re-check that `scannerUid` is one of the match's
 *      `participants` — which closes the loophole of scanning a token for a
 *      match you are not a party to.
 *   4. SINGLE-USE — inside a `db.runTransaction` we query
 *      `/trades/ where jwtTokenHash == sha256(token)`. If anything matches,
 *      the token has already been redeemed and we throw ALREADY_USED. The
 *      query MUST live inside the transaction so two concurrent scans of
 *      the same token cannot both pass the check.
 *
 * On success the function delegates to `writeTradeAndImpact` (WBS 10.6) to
 * write the /trades/ doc, flip both items to traded, and increment the six
 * counter fields on /users/. The match is then flipped to status='completed'
 * in the same transaction. Returns `{ success: true, tradeId }`.
 *
 * Error code mapping (typed string in the HttpsError message; the typed
 * `code` field carries the canonical Firebase error code):
 *
 *   INVALID_SIGNATURE   → permission-denied
 *   EXPIRED             → deadline-exceeded
 *   WRONG_COUNTERPARTY  → permission-denied
 *   ALREADY_USED        → already-exists
 *   MATCH_INVALID       → failed-precondition
 *
 * Locked decisions enforced here (CLAUDE.md + WBS 10.2):
 *   - The single-use query lives inside `runTransaction`. The pseudocode in
 *     WBS 10.2 puts it first inside the tx body for a reason: two concurrent
 *     scans must not both observe an empty `/trades/` result.
 *   - Algorithm pinned to HS256 in `jwt.verify` to prevent an alg='none'
 *     downgrade attack.
 *   - No DEV_MODE bypass on the server. The paste-token client fallback
 *     (10.5) routes through this same function with the same JWT; we treat
 *     every token the same regardless of arrival path.
 *   - The five error code STRINGS are fixed by the WBS entry — do NOT invent
 *     new ones, do NOT rename them. The 10.4 scan screen maps these strings
 *     to user-facing toast text.
 *   - This function (with the 10.6 helper it calls) is the ONLY writer of
 *     /trades/ and the /users/ counter fields. Server-side only.
 */

import { createHash } from "crypto";

import { onCall, HttpsError, CallableRequest } from "firebase-functions/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as jwt from "jsonwebtoken";

import { JWT_SECRET } from "./secrets";
import type { MatchDoc, JwtPayload } from "./types";
import { writeTradeAndImpact } from "./writeTradeAndImpact";

/** Request payload shape for `validateQRToken`. */
export interface ValidateQRTokenData {
  token: string;
}

/** Response shape returned to the caller on success. */
export interface ValidateQRTokenResult {
  success: true;
  tradeId: string;
}

/**
 * SHA-256 hex digest of the raw JWT string. The result is written to
 * `/trades/{*}.jwtTokenHash` and queried inside the transaction to enforce
 * single-use. We use the hex digest (not base64) so the value is consistent
 * across any tool that later inspects the document.
 */
export function sha256(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

/**
 * Pure handler exposed for unit testing. Takes the secret value as a thunk
 * so tests can drive it without going through Secret Manager (which is not
 * available in the local Jest process). Mirrors the pattern used in
 * `handleIssueQRToken` in WBS 10.1.
 *
 * The order of checks is deliberate and locked:
 *   1. auth present (unauthenticated)
 *   2. token argument present (invalid-argument)
 *   3. jwt.verify — signature + expiry (INVALID_SIGNATURE | EXPIRED)
 *   4. displayer !== scanner (WRONG_COUNTERPARTY)
 *   5. enter transaction
 *   6.   single-use check (ALREADY_USED)
 *   7.   match exists + active (MATCH_INVALID)
 *   8.   scanner in match.participants (WRONG_COUNTERPARTY)
 *   9.   writeTradeAndImpact (WBS 10.6)
 *  10.   flip match to completed
 *
 * Steps 6 through 10 all live inside the same transaction so they commit
 * atomically. The single-use query at step 6 is what prevents two concurrent
 * validate calls of the same token from both succeeding.
 */
export async function handleValidateQRToken(
  scannerUid: string | undefined,
  data: Partial<ValidateQRTokenData>,
  getJwtSecret: () => string,
): Promise<ValidateQRTokenResult> {
  if (!scannerUid) {
    throw new HttpsError("unauthenticated", "auth required");
  }
  const token = data?.token;
  if (!token || typeof token !== "string") {
    throw new HttpsError("invalid-argument", "token required");
  }

  // CHECK 1 + 2: signature and expiry. `jwt.verify` checks both in one call.
  // We pin the algorithm to HS256 to prevent an alg='none' downgrade where a
  // forged token with no signature would otherwise pass verification.
  let payload: JwtPayload;
  try {
    payload = jwt.verify(token, getJwtSecret(), {
      algorithms: ["HS256"],
    }) as JwtPayload;
  } catch (e) {
    if (e instanceof jwt.TokenExpiredError) {
      throw new HttpsError("deadline-exceeded", "EXPIRED");
    }
    // Any other verify failure — bad signature, malformed token, wrong
    // algorithm — maps to INVALID_SIGNATURE. We intentionally do not leak
    // the underlying jsonwebtoken error message to the client.
    throw new HttpsError("permission-denied", "INVALID_SIGNATURE");
  }

  // CHECK 3 (part 1): the scanner must not be the user who issued the QR.
  // We check this BEFORE the transaction because it requires no Firestore
  // read; failing fast here is cheaper. The transaction will also re-check
  // that the scanner is in match.participants — that closes the loophole of
  // a third-party who somehow obtained a token for a match they don't belong
  // to (e.g. the displayer accidentally screenshared it).
  if (payload.displayerUserId === scannerUid) {
    throw new HttpsError("permission-denied", "WRONG_COUNTERPARTY");
  }

  const tokenHash = sha256(token);
  const db = getFirestore();

  return await db.runTransaction(async (tx) => {
    // CHECK 4: single-use. The query lives INSIDE the transaction so two
    // concurrent scans of the same token cannot both see an empty result.
    // Firestore's transaction semantics serialise the read+write set —
    // whichever call commits second will retry and observe the trade doc
    // created by the first.
    const existing = await tx.get(
      db.collection("trades").where("jwtTokenHash", "==", tokenHash).limit(1),
    );
    if (!existing.empty) {
      throw new HttpsError("already-exists", "ALREADY_USED");
    }

    // Read the match inside the transaction so a status flip happening
    // concurrently elsewhere triggers a transaction retry rather than a
    // stale-read race.
    const matchRef = db.doc(`matches/${payload.matchId}`);
    const matchSnap = await tx.get(matchRef);
    const m = matchSnap.data() as MatchDoc | undefined;
    if (!m || m.status !== "active") {
      throw new HttpsError("failed-precondition", "MATCH_INVALID");
    }

    // CHECK 3 (part 2): scanner is a party to the match. A token whose
    // displayerUserId is bob and whose scannerUid is charlie (not in
    // participants) must also fail with WRONG_COUNTERPARTY.
    if (!m.participants.includes(scannerUid)) {
      throw new HttpsError("permission-denied", "WRONG_COUNTERPARTY");
    }

    // Delegate to WBS 10.6: write the trade doc with structured impact,
    // flip both items to status='traded', and increment the six counter
    // fields on /users/. All writes go through `tx` so they commit
    // atomically with the match-completion update below.
    const tradeId = await writeTradeAndImpact(tx, m, payload.matchId, tokenHash);

    tx.update(matchRef, {
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
    });

    return { success: true, tradeId };
  });
}

/**
 * v2 callable wrapper. Binds the JWT_SECRET so Cloud Functions runtime
 * mounts it from Secret Manager, then delegates to `handleValidateQRToken`.
 */
export const validateQRToken = onCall<ValidateQRTokenData>(
  { secrets: [JWT_SECRET] },
  async (request: CallableRequest<ValidateQRTokenData>) => {
    return handleValidateQRToken(
      request.auth?.uid,
      request.data,
      () => JWT_SECRET.value(),
    );
  },
);
