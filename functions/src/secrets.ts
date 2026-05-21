/**
 * Firebase Secret Manager bindings, extracted from `index.ts` to avoid
 * circular imports between callable modules (e.g. `issueQRToken.ts`) and the
 * top-level entry point that re-exports them.
 *
 * Per CLAUDE.md and WBS 3.5, the QR signing key is provisioned via
 *
 *     firebase functions:secrets:set JWT_SECRET
 *
 * The secret value is read inside a function at request time via
 * `JWT_SECRET.value()`. Reading it at module load throws — that's by design,
 * and it keeps tests and the local Functions Shell from accidentally pulling
 * in production credentials.
 */

import { defineSecret } from "firebase-functions/params";

export const JWT_SECRET = defineSecret("JWT_SECRET");
