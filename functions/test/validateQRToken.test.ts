/**
 * WBS 10.2 — validateQRToken tests.
 *
 * Verifies the six Testing criteria from the WBS 10.2 entry:
 *   1. Forged token (wrong signing key)            → INVALID_SIGNATURE
 *   2. Token issued 61s ago                        → EXPIRED
 *   3. Scanner is the displayer (own QR)           → WRONG_COUNTERPARTY
 *   4. Same token validated twice (single-use)     → second call ALREADY_USED
 *   5. Match already completed                     → MATCH_INVALID
 *   6. Integration test of the full happy path     → trade exists, items
 *      flipped, counters incremented. This last test depends on WBS 10.6's
 *      `writeTradeAndImpact` helper landing — until then it is marked
 *      `test.skip` with a TODO. The five error-path tests above all throw
 *      before reaching the helper, so they pass against the WBS 10.2 code on
 *      its own.
 *
 * The handler talks to the Firestore emulator via the Admin SDK (running
 * because `npm test` wraps Jest in
 *   `firebase emulators:exec --only firestore,storage --project demo-ecoswap`
 * ). We exercise `handleValidateQRToken` directly with a thunk-supplied
 * secret — Secret Manager is not available inside the local Jest process,
 * and the thunk pattern mirrors the v2 callable wrapper without requiring
 * the Functions framework to be running.
 *
 * The error-code mapping under test (locked by WBS 10.2):
 *   INVALID_SIGNATURE   → HttpsError code 'permission-denied'
 *   EXPIRED             → HttpsError code 'deadline-exceeded'
 *   WRONG_COUNTERPARTY  → HttpsError code 'permission-denied'
 *   ALREADY_USED        → HttpsError code 'already-exists'
 *   MATCH_INVALID       → HttpsError code 'failed-precondition'
 *
 * The message string also carries the canonical token (e.g. 'EXPIRED'), so we
 * assert both fields to catch a future refactor that accidentally returns the
 * right Firebase code with the wrong message string.
 */

import { initializeApp, getApps, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";
import * as jwt from "jsonwebtoken";

import { handleValidateQRToken, sha256 } from "../src/validateQRToken";
import type { MatchDoc, ItemDoc, JwtPayload, TradeDoc } from "../src/types";

const PROJECT_ID = "demo-ecoswap";
const TEST_SECRET = "test-jwt-secret-not-a-real-key";

// Point the Admin SDK at the local Firestore emulator before any call.
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

beforeAll(() => {
  if (getApps().length === 0) {
    initializeApp({ projectId: PROJECT_ID });
  }
});

afterAll(async () => {
  await Promise.all(getApps().map((app) => deleteApp(app)));
});

async function resetFirestore(): Promise<void> {
  const db = getFirestore();
  for (const coll of ["matches", "items", "trades", "users"]) {
    const snap = await db.collection(coll).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

beforeEach(async () => {
  await resetFirestore();
});

/** Build a valid /items/{id} doc, defaulting to status 'active'. */
function itemDoc(ownerId: string, overrides: Partial<ItemDoc> = {}): ItemDoc {
  return {
    ownerId,
    name: "Test Item",
    category: "other",
    condition: "good",
    weight: null,
    description: null,
    wants: null,
    photoUrl: "",
    status: "active",
    createdAt: Timestamp.now(),
    ...overrides,
  };
}

/** Build a valid /matches/{id} doc with sensible defaults. */
function matchDoc(overrides: Partial<MatchDoc> = {}): MatchDoc {
  return {
    userAId: "alice",
    userBId: "bob",
    userAWantsItemId: "itemX",
    userBWantsItemId: "itemY",
    status: "active",
    participants: ["alice", "bob"],
    createdAt: Timestamp.now(),
    completedAt: null,
    ...overrides,
  };
}

/**
 * Seed the typical happy-path fixture: match alice<->bob with two active
 * items. Individual tests override specific fields to drive failure paths.
 */
async function seedHappyPathFixture(opts: {
  matchOverrides?: Partial<MatchDoc>;
} = {}): Promise<void> {
  const db = getFirestore();
  await db.doc("items/itemX").set(itemDoc("bob"));
  await db.doc("items/itemY").set(itemDoc("alice"));
  await db.doc("matches/m1").set(matchDoc(opts.matchOverrides));
}

/**
 * Sign a JWT with the documented payload shape. Allows individual tests to
 * back-date `iat`/`exp` for the EXPIRED test and to override the
 * displayerUserId for the WRONG_COUNTERPARTY test.
 */
function signToken(
  overrides: Partial<JwtPayload> = {},
  secret: string = TEST_SECRET,
): string {
  const now = Math.floor(Date.now() / 1000);
  const payload: JwtPayload = {
    matchId: "m1",
    displayerUserId: "alice",
    iat: now,
    exp: now + 60,
    ...overrides,
  };
  return jwt.sign(payload, secret, { algorithm: "HS256" });
}

/**
 * Helper that asserts the handler throws an HttpsError with a specific code
 * AND message. The WBS 10.2 entry locks both the Firebase code and the
 * message string (e.g. 'EXPIRED'); a future refactor that gets only one
 * right would still ship a regression to the 10.4 scan screen's error toast.
 */
async function expectHttpsError(
  promise: Promise<unknown>,
  code: HttpsError["code"],
  message: string,
): Promise<void> {
  await expect(promise).rejects.toMatchObject({ code, message });
}

describe("WBS 10.2 — validateQRToken", () => {
  test("forged token (wrong signing key) → INVALID_SIGNATURE", async () => {
    await seedHappyPathFixture();
    // Sign with the wrong key. The payload shape is otherwise valid.
    const forged = signToken({}, "definitely-not-the-real-secret");

    await expectHttpsError(
      handleValidateQRToken("bob", { token: forged }, () => TEST_SECRET),
      "permission-denied",
      "INVALID_SIGNATURE",
    );
  });

  test("token issued 61s ago → EXPIRED", async () => {
    await seedHappyPathFixture();
    const now = Math.floor(Date.now() / 1000);
    // iat 61s ago, exp 1s ago — both definitely before "now".
    const expired = signToken({ iat: now - 61, exp: now - 1 });

    await expectHttpsError(
      handleValidateQRToken("bob", { token: expired }, () => TEST_SECRET),
      "deadline-exceeded",
      "EXPIRED",
    );
  });

  test("scanner is the displayer → WRONG_COUNTERPARTY", async () => {
    await seedHappyPathFixture();
    // Alice issued the token; alice also scans it (e.g. she scanned her own
    // QR by accident). The displayer-vs-scanner check should reject before
    // the transaction even opens.
    const token = signToken({ displayerUserId: "alice" });

    await expectHttpsError(
      handleValidateQRToken("alice", { token }, () => TEST_SECRET),
      "permission-denied",
      "WRONG_COUNTERPARTY",
    );
  });

  test("scanner not in match.participants → WRONG_COUNTERPARTY", async () => {
    // Defence-in-depth: even if a third party (charlie) somehow obtained a
    // valid token for alice<->bob's match, the in-transaction
    // participants-check must reject.
    await seedHappyPathFixture();
    const token = signToken({ displayerUserId: "alice" });

    await expectHttpsError(
      handleValidateQRToken("charlie", { token }, () => TEST_SECRET),
      "permission-denied",
      "WRONG_COUNTERPARTY",
    );
  });

  test("match already completed → MATCH_INVALID", async () => {
    await seedHappyPathFixture({
      matchOverrides: { status: "completed", completedAt: Timestamp.now() },
    });
    const token = signToken({ displayerUserId: "alice" });

    await expectHttpsError(
      handleValidateQRToken("bob", { token }, () => TEST_SECRET),
      "failed-precondition",
      "MATCH_INVALID",
    );
  });

  test("match cancelled → MATCH_INVALID", async () => {
    // Same error code surface as 'completed' — both are non-active terminal
    // states that should reject token redemption.
    await seedHappyPathFixture({ matchOverrides: { status: "cancelled" } });
    const token = signToken({ displayerUserId: "alice" });

    await expectHttpsError(
      handleValidateQRToken("bob", { token }, () => TEST_SECRET),
      "failed-precondition",
      "MATCH_INVALID",
    );
  });

  test("missing match doc → MATCH_INVALID", async () => {
    // No fixture seeded — token points at a nonexistent match.
    const token = signToken({ displayerUserId: "alice", matchId: "nope" });

    await expectHttpsError(
      handleValidateQRToken("bob", { token }, () => TEST_SECRET),
      "failed-precondition",
      "MATCH_INVALID",
    );
  });

  test("same token validated twice → second call ALREADY_USED", async () => {
    // We seed an existing /trades/ doc whose jwtTokenHash matches the token
    // about to be validated. This simulates the "second-call" branch without
    // depending on WBS 10.6's writeTradeAndImpact helper to perform the
    // first-call write (which currently throws 'unimplemented' as a stub).
    //
    // This is the critical single-use guarantee: the query that powers it
    // lives INSIDE the runTransaction in `validateQRToken.ts`. A naive
    // implementation that put the check outside the transaction would let
    // two concurrent scans both pass step 4.
    await seedHappyPathFixture();
    const token = signToken({ displayerUserId: "alice" });
    const tokenHash = sha256(token);

    const db = getFirestore();
    const preExisting: TradeDoc = {
      matchId: "m1",
      completedAt: Timestamp.now(),
      jwtTokenHash: tokenHash,
      impact: {
        userAGains: { userId: "alice", co2Saved: 0, wasteDiverted: 0 },
        userBGains: { userId: "bob", co2Saved: 0, wasteDiverted: 0 },
      },
      itemsExchanged: { fromA: "itemX", fromB: "itemY" },
    };
    await db.collection("trades").add(preExisting);

    await expectHttpsError(
      handleValidateQRToken("bob", { token }, () => TEST_SECRET),
      "already-exists",
      "ALREADY_USED",
    );
  });

  test("missing token argument → invalid-argument", async () => {
    // Defensive: the v2 callable framework will type-check `data.token` to a
    // string, but a malicious client could still send `{}`. We reject before
    // jwt.verify, which would otherwise throw a generic JsonWebTokenError.
    await expectHttpsError(
      handleValidateQRToken("bob", {}, () => TEST_SECRET),
      "invalid-argument",
      "token required",
    );
  });

  test("missing auth → unauthenticated", async () => {
    // The v2 callable wrapper extracts request.auth?.uid; if no auth was
    // provided, scannerUid is undefined and the handler must reject before
    // even touching the token.
    await expectHttpsError(
      handleValidateQRToken(undefined, { token: "any" }, () => TEST_SECRET),
      "unauthenticated",
      "auth required",
    );
  });

  // -------------------------------------------------------------------------
  // Integration: full happy path. Depends on WBS 10.6.
  //
  // The WBS 10.2 Testing section requires:
  //   "Integration test: full flow A issues → B validates → trade exists,
  //    both items flipped, counters incremented"
  //
  // The trade write, item flips, and counter increments live inside
  // `writeTradeAndImpact` (WBS 10.6), which is currently a stub that throws
  // 'unimplemented'. Re-enable this test by removing `.skip` once WBS 10.6
  // lands. The five error-path tests above all reject BEFORE reaching the
  // helper and are therefore unaffected by the stub.
  // -------------------------------------------------------------------------
  test.skip("integration: valid scan writes trade, flips items, increments counters", async () => {
    // When 10.6 lands, this test should:
    //   1. Seed /users/alice and /users/bob with all 3 counters at 0
    //   2. Seed two /items/ with known weights and categories so the impact
    //      math is predictable (e.g. the worked example from WBS 11.1).
    //   3. Sign a token with alice as displayer.
    //   4. Call handleValidateQRToken('bob', { token }, () => TEST_SECRET).
    //   5. Assert { success: true, tradeId: <string> }.
    //   6. Assert /trades/{tradeId} exists with the right matchId,
    //      jwtTokenHash, impact object, and itemsExchanged.
    //   7. Assert both items now have status='traded'.
    //   8. Assert /matches/m1 has status='completed' and a completedAt
    //      timestamp.
    //   9. Assert /users/alice and /users/bob each have tradesCount=1 and
    //      the expected co2/waste deltas.
    expect(true).toBe(true);
  });
});
