/**
 * Unit tests for the Cloud Functions scaffold (WBS 3.5).
 *
 * Verifies that the three required function exports (`issueQRToken`,
 * `validateQRToken`, `onTradeComplete`) are present with the expected
 * callable / trigger shape and that the `JWT_SECRET` binding is wired to
 * Secret Manager (not to `process.env`).
 *
 * Real behavioural tests for these functions live in their own files:
 *   - WBS 10.1 → `test/issueQRToken.test.ts`
 *   - WBS 10.2 → `test/validateQRToken.test.ts`
 *   - WBS 10.6 → arrives with that task
 * This file only covers the scaffolding Acceptance criteria from 3.5.
 */

import * as functionsModule from "../src/index";

describe("WBS 3.5 — Cloud Functions environment scaffold", () => {
  test("exports the three required function names", () => {
    expect(functionsModule).toHaveProperty("issueQRToken");
    expect(functionsModule).toHaveProperty("validateQRToken");
    expect(functionsModule).toHaveProperty("onTradeComplete");
  });

  test("exports the JWT_SECRET Secret Manager binding", () => {
    expect(functionsModule).toHaveProperty("JWT_SECRET");
    // SecretParam has a `name` of 'JWT_SECRET' — this confirms we used
    // defineSecret('JWT_SECRET') rather than reading process.env.
    const secret = functionsModule.JWT_SECRET as { name?: string };
    expect(secret).toBeDefined();
    expect(secret.name).toBe("JWT_SECRET");
  });

  test("issueQRToken is a callable Cloud Function", () => {
    // v2 onCall functions expose a `run` method and a `__endpoint` descriptor
    // with `callableTrigger` set. We assert on `run` because it is the
    // public, stable surface.
    const fn = functionsModule.issueQRToken as unknown as { run?: unknown };
    expect(typeof fn.run).toBe("function");
  });

  test("validateQRToken is a callable Cloud Function", () => {
    const fn = functionsModule.validateQRToken as unknown as { run?: unknown };
    expect(typeof fn.run).toBe("function");
  });

  test("onTradeComplete is a Firestore-triggered Cloud Function", () => {
    // onDocumentCreated wraps the handler and exposes a `run` method.
    const fn = functionsModule.onTradeComplete as unknown as { run?: unknown };
    expect(typeof fn.run).toBe("function");
  });

  // Note: `issueQRToken` is implemented in WBS 10.1 (see
  // `test/issueQRToken.test.ts` for behavioural tests). The unauthenticated
  // and authenticated-with-real-Firestore paths are exercised there.

  test("issueQRToken rejects unauthenticated callers", async () => {
    // Construct a minimal CallableRequest-like object with no auth.
    // The real 10.1 implementation also throws HttpsError('unauthenticated').
    const fn = functionsModule.issueQRToken as unknown as {
      run: (req: unknown) => Promise<unknown>;
    };
    await expect(
      fn.run({ data: {}, auth: undefined, rawRequest: {} }),
    ).rejects.toThrow(/auth required/);
  });

  // Note: `validateQRToken` is implemented in WBS 10.2 (see
  // `test/validateQRToken.test.ts` for the full behavioural test suite that
  // covers all five typed error codes — INVALID_SIGNATURE, EXPIRED,
  // WRONG_COUNTERPARTY, ALREADY_USED, MATCH_INVALID — plus the single-use
  // single-use transaction guarantee). The scaffold test below only asserts
  // the unauthenticated path, which matches the issueQRToken pattern above.

  test("validateQRToken rejects unauthenticated callers", async () => {
    const fn = functionsModule.validateQRToken as unknown as {
      run: (req: unknown) => Promise<unknown>;
    };
    await expect(
      fn.run({ data: { token: "x" }, auth: undefined, rawRequest: {} }),
    ).rejects.toThrow(/auth required/);
  });
});
