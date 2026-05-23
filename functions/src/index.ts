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
import { onDocumentCreated } from "firebase-functions/firestore";

import { JWT_SECRET } from "./secrets";

// Initialise the Admin SDK exactly once. `onSwipeCreated.ts` also guards this,
// but performing it here too keeps the import graph order-independent: any
// callable function that imports the secret via `./index` gets an initialised
// `getFirestore()` regardless of which module loaded first.
import { initializeApp, getApps } from "firebase-admin/app";
if (getApps().length === 0) {
  initializeApp();
}

// Cap concurrent containers — keeps a runaway loop from torching the budget.
// Per-function overrides happen in 10.1 / 10.2 / 10.6 if needed.
setGlobalOptions({ maxInstances: 10 });

/**
 * Re-export the Secret Manager binding for the QR-exchange JWT signing key.
 *
 * The binding itself lives in `./secrets` to keep the import graph acyclic:
 * `issueQRToken.ts` (and later `validateQRToken.ts`) need the secret without
 * pulling in the rest of `index.ts`.
 *
 * Provisioning is documented in `functions/README.md`:
 *
 *     firebase functions:secrets:set JWT_SECRET
 *
 * Reading the value at module load throws; that's by design.
 */
export { JWT_SECRET };

// WBS 10.1 — issueQRToken now has a real implementation in `./issueQRToken`.
// WBS 10.2 — validateQRToken now has a real implementation in
// `./validateQRToken`. Both are re-exported below so Cloud Functions sees the
// same export names.

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

// WBS 10.1 — issueQRToken callable. Real implementation lives in its own
// module to keep `index.ts` lean.
export { issueQRToken } from "./issueQRToken";

// WBS 10.2 — validateQRToken callable. Real implementation lives in its own
// module to keep `index.ts` lean.
export { validateQRToken } from "./validateQRToken";

// WBS 8.5 — Hard-Cancel Pending Swipes When Item Traded. Re-export the
// Firestore-update trigger so the Functions framework picks it up and
// `firebase deploy --only functions` includes it.
export { onItemTraded } from "./onItemTraded";
