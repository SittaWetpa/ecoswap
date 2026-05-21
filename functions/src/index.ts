/**
 * EcoSwap Cloud Functions — entry point (WBS 3.5).
 *
 * This file is the scaffolding for the three Cloud Functions the QR-exchange
 * and impact-attribution flows depend on:
 *
 *   - `issueQRToken`    — implemented in WBS 10.1 (HS256-signed JWT)
 *   - `validateQRToken` — implemented in WBS 10.2 (four security checks)
 *   - `onTradeComplete` — implemented in WBS 10.6 (transactional /trades/
 *                         writer and /users/ counter updater)
 *
 * Per the locked decisions in `CLAUDE.md`:
 *   - The JWT signing key lives in Firebase Secret Manager, NEVER in a `.env`
 *     file. The binding below is the only place that reference is created.
 *   - Counter fields on /users/ (`tradesCount`, `totalCo2Saved`,
 *     `totalWasteDiverted`) are written ONLY by `onTradeComplete`.
 *
 * The stubs currently:
 *   1. Verify the caller is authenticated (callable functions only).
 *   2. Throw `HttpsError('unimplemented', ...)` pointing at the WBS task that
 *      will fill them in.
 *
 * This is enough to make `firebase deploy --only functions` succeed and to
 * smoke-test the function shapes from the Functions Shell.
 */

import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/https";
import { onDocumentCreated } from "firebase-functions/firestore";
import { defineSecret } from "firebase-functions/params";

// Cap concurrent containers — keeps a runaway loop from torching the budget.
// Per-function overrides happen in 10.1 / 10.2 / 10.6 if needed.
setGlobalOptions({ maxInstances: 10 });

/**
 * Firebase Secret Manager binding for the QR-exchange JWT signing key.
 *
 * Provisioning is documented in `functions/README.md`:
 *
 *     firebase functions:secrets:set JWT_SECRET
 *
 * The value is read inside a function via `JWT_SECRET.value()` at request
 * time. Reading at module top level throws; that's by design.
 */
export const JWT_SECRET = defineSecret("JWT_SECRET");

/** Request payload shape for `issueQRToken` (filled in by WBS 10.1). */
interface IssueQRTokenData {
  matchId: string;
}

/** Request payload shape for `validateQRToken` (filled in by WBS 10.2). */
interface ValidateQRTokenData {
  token: string;
}

/**
 * `issueQRToken` — issue a short-lived HS256 JWT for a confirmed match.
 *
 * Full implementation lands in WBS 10.1. The stub here only enforces the
 * auth check so the Acceptance criterion "Function stubs can be invoked from
 * the Functions Shell and return placeholder responses" is satisfied.
 */
export const issueQRToken = onCall<IssueQRTokenData>(
  { secrets: [JWT_SECRET] },
  async (request: CallableRequest<IssueQRTokenData>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "auth required");
    }
    throw new HttpsError(
      "unimplemented",
      "issueQRToken stub — real implementation lands in WBS 10.1",
    );
  },
);

/**
 * `validateQRToken` — validate a scanned QR token and (in 10.2) atomically
 * mark the match completed, write the /trades/ doc, and update counters.
 *
 * The stub enforces the auth check and returns `unimplemented`.
 */
export const validateQRToken = onCall<ValidateQRTokenData>(
  { secrets: [JWT_SECRET] },
  async (request: CallableRequest<ValidateQRTokenData>) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "auth required");
    }
    throw new HttpsError(
      "unimplemented",
      "validateQRToken stub — real implementation lands in WBS 10.2",
    );
  },
);

/**
 * `onTradeComplete` — Firestore trigger on `/trades/{tradeId}` create.
 *
 * In WBS 10.6 this becomes the sole writer of the denormalised counters on
 * /users/. The stub here only logs and returns so the deploy-time wiring is
 * exercised.
 */
export const onTradeComplete = onDocumentCreated(
  "trades/{tradeId}",
  async (_event) => {
    // Intentionally a no-op stub. WBS 10.6 will:
    //   - run db.runTransaction
    //   - read the two participating /items/ for category + weight
    //   - compute CO2 + waste using functions/src/constants/impact.ts
    //   - increment /users/{a}.tradesCount, totalCo2Saved, totalWasteDiverted
    //   - same for /users/{b}
    return;
  },
);

// WBS 8.3 — Mutual Swipe Detection. Re-export the trigger so the Functions
// framework picks it up and `firebase deploy --only functions` includes it.
export { onSwipeCreated } from "./onSwipeCreated";
