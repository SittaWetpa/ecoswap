/**
 * Unit tests for the Cloud Functions scaffold (WBS 3.5).
 *
 * Verifies that the three function stubs (`issueQRToken`, `validateQRToken`,
 * `onTradeComplete`) are exported with the expected callable / trigger shape
 * and that the `JWT_SECRET` binding is wired to Secret Manager (not to
 * `process.env`).
 *
 * Real behavioural tests for these functions arrive in WBS 10.1, 10.2, and
 * 10.6 — they will use the Firestore + Auth emulator. This file only covers
 * the scaffolding Acceptance criteria from 3.5.
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

  test("validateQRToken stub rejects unauthenticated callers", async () => {
    const fn = functionsModule.validateQRToken as unknown as {
      run: (req: unknown) => Promise<unknown>;
    };
    await expect(
      fn.run({ data: { token: "x" }, auth: undefined, rawRequest: {} }),
    ).rejects.toThrow(/auth required/);
  });

  test("validateQRToken stub returns unimplemented for authenticated callers", async () => {
    const fn = functionsModule.validateQRToken as unknown as {
      run: (req: unknown) => Promise<unknown>;
    };
    await expect(
      fn.run({
        data: { token: "x" },
        auth: { uid: "bob", token: {} },
        rawRequest: {},
      }),
    ).rejects.toThrow(/WBS 10\.2/);
  });
});
