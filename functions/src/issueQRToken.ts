/**
 * WBS 10.1 — Cloud Function: Issue Signed JWT for QR Exchange.
 *
 * Callable Cloud Function. Given a `matchId`, validates that the caller is a
 * party to that match, that the match is still `status: 'active'`, and that
 * both declared items are still `status: 'active'`. Returns an HS256-signed
 * JWT with a 60-second lifetime. The signing key comes from Firebase Secret
 * Manager (`JWT_SECRET`, bound in `index.ts`) — NEVER from a `.env` file or a
 * hard-coded constant.
 *
 * Locked decisions enforced here (CLAUDE.md + WBS 10.1):
 *   - Algorithm: HS256. Hard-coded; do not accept caller-provided alg.
 *   - Payload fields: matchId, displayerUserId, iat, exp. Exact names — these
 *     are data-layer ("trade") vocabulary, not UI ("swap") vocabulary.
 *   - `exp` is exactly `iat + 60`. Set both fields explicitly on the payload
 *     rather than relying on `jsonwebtoken`'s `expiresIn` option (the WBS
 *     Testing section asserts the exact relationship).
 *   - Single-use enforcement does NOT live here. It is the 10.2 validate
 *     function's job to reject already-used tokens via /trades/{*}.jwtTokenHash.
 *     We intentionally write nothing to /trades/ at issue time.
 *   - No DEV_MODE bypass. The paste-token client fallback (10.5) routes
 *     through the same 10.2 validate path; the server treats every token the
 *     same regardless of how it arrived at the scanner.
 *
 * The four validation failures map to HttpsError codes:
 *   - caller not in match.participants     → permission-denied
 *   - match.status !== 'active'            → failed-precondition
 *   - either declared item.status !== 'active' → failed-precondition
 *   - missing /matches/{matchId} document  → not-found
 *
 * Returns `{ token: string, expiresAt: number }` where `expiresAt` is unix
 * seconds (== payload.exp). The client uses `expiresAt` to drive the
 * 60-second countdown in 10.3.
 */

import { onCall, HttpsError, CallableRequest } from "firebase-functions/https";
import { getFirestore } from "firebase-admin/firestore";
import * as jwt from "jsonwebtoken";

import { JWT_SECRET } from "./secrets";
import type { MatchDoc, ItemDoc, JwtPayload } from "./types";

/** Request payload shape for `issueQRToken`. */
export interface IssueQRTokenData {
  matchId: string;
}

/** Response shape returned to the caller on success. */
export interface IssueQRTokenResult {
  token: string;
  expiresAt: number; // unix seconds; equals payload.exp
}

/**
 * Pure handler exposed for unit testing. Takes the secret value as an
 * argument so tests can drive it without going through Secret Manager (which
 * is not available in the local Jest process).
 *
 * The four runtime checks are performed in the order:
 *   1. auth present
 *   2. matchId present
 *   3. match document exists
 *   4. caller is in match.participants
 *   5. match.status === 'active'
 *   6. both declared items still status === 'active'
 *
 * Each failure throws a typed HttpsError so the v2 callable framework
 * surfaces the right code and message to the client.
 */
export async function handleIssueQRToken(
  uid: string | undefined,
  data: Partial<IssueQRTokenData>,
  /**
   * Lazy accessor for the signing key. Passed as a thunk so the
   * unauthenticated and "match missing" / "not a party" paths never read
   * `JWT_SECRET.value()` — keeps tests that do not provision Secret Manager
   * able to drive those failure paths.
   */
  getJwtSecret: () => string,
  now: number = Math.floor(Date.now() / 1000),
): Promise<IssueQRTokenResult> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "auth required");
  }
  const matchId = data?.matchId;
  if (!matchId || typeof matchId !== "string") {
    throw new HttpsError("invalid-argument", "matchId required");
  }

  const db = getFirestore();
  const matchSnap = await db.doc(`matches/${matchId}`).get();
  const m = matchSnap.data() as MatchDoc | undefined;
  if (!m) {
    throw new HttpsError("not-found", "no such match");
  }
  if (!m.participants.includes(uid)) {
    throw new HttpsError("permission-denied", "not a party");
  }
  if (m.status !== "active") {
    throw new HttpsError("failed-precondition", "match not active");
  }

  // Defensive: both declared items must still be 'active'. If either was
  // traded away in another flow (8.5), we refuse to issue a token rather
  // than letting 10.2 fail later. Cheaper to fail at issue.
  const itemIds = [m.userAWantsItemId, m.userBWantsItemId];
  for (const id of itemIds) {
    const itemSnap = await db.doc(`items/${id}`).get();
    const item = itemSnap.data() as ItemDoc | undefined;
    if (!item || item.status !== "active") {
      throw new HttpsError("failed-precondition", "item no longer available");
    }
  }

  // Build the payload by hand so `exp === iat + 60` exactly. Using
  // jsonwebtoken's `expiresIn: '60s'` option would set `exp` relative to a
  // freshly-computed `iat` inside the library, and we want a single source
  // of truth for `now`.
  const exp = now + 60;
  const payload: JwtPayload = {
    matchId,
    displayerUserId: uid,
    iat: now,
    exp,
  };
  // We set `iat` and `exp` explicitly in the payload. jsonwebtoken respects
  // a caller-supplied `iat` when present; it would only auto-fill when the
  // field is missing. Crucially we do NOT pass `noTimestamp: true` — that
  // option strips `iat` from the final token, which we want to keep.
  const token = jwt.sign(payload, getJwtSecret(), {
    algorithm: "HS256",
  });

  return { token, expiresAt: exp };
}

/**
 * v2 callable wrapper. Binds the JWT_SECRET so Cloud Functions runtime
 * mounts it from Secret Manager, then delegates to `handleIssueQRToken`.
 */
export const issueQRToken = onCall<IssueQRTokenData>(
  { secrets: [JWT_SECRET] },
  async (request: CallableRequest<IssueQRTokenData>) => {
    return handleIssueQRToken(
      request.auth?.uid,
      request.data,
      () => JWT_SECRET.value(),
    );
  },
);
