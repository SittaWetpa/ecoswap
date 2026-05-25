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
  // This drives `handleValidateQRToken` end-to-end against the local
  // emulator. WBS 10.6's writeTradeAndImpact now performs the trade write,
  // the item flips, and the counter increments — so this test exercises
  // the full transaction (10.2's match read + 10.6's writes + 10.2's
  // match-status flip) in a single call.
  //
  // Uses the worked example from WBS 11.1:
  //   alice (=A) gives a denim jacket (clothing, 0.6 kg) → itemX
  //   bob   (=B) gives an electric kettle (kitchenware, 1.2 kg) → itemY
  // so the expected attribution is:
  //   alice: co2 = 1.2 * 6 = 7.2, waste = 0.6
  //   bob:   co2 = 0.6 * 25 = 15,  waste = 1.2
  // -------------------------------------------------------------------------
  test("integration: valid scan writes trade, flips items, increments counters", async () => {
    const db = getFirestore();

    // itemX is what B (bob) wants — so it's alice's item.
    await db.doc("items/itemX").set({
      ownerId: "alice",
      name: "Denim Jacket",
      category: "clothing",
      condition: "good",
      weight: 0.6,
      description: null,
      wants: null,
      photoUrl: "",
      status: "active",
      createdAt: Timestamp.now(),
    } as ItemDoc);
    // itemY is what A (alice) wants — so it's bob's item.
    await db.doc("items/itemY").set({
      ownerId: "bob",
      name: "Electric Kettle",
      category: "kitchenware",
      condition: "good",
      weight: 1.2,
      description: null,
      wants: null,
      photoUrl: "",
      status: "active",
      createdAt: Timestamp.now(),
    } as ItemDoc);
    await db.doc("matches/m1").set({
      userAId: "alice",
      userBId: "bob",
      userAWantsItemId: "itemY",
      userBWantsItemId: "itemX",
      status: "active",
      participants: ["alice", "bob"],
      createdAt: Timestamp.now(),
      completedAt: null,
    } as MatchDoc);

    // Seed both users with all three counters at zero so the post-commit
    // deltas are exactly the impact numbers (no add-to-existing math).
    const baseUser = {
      email: "",
      photoUrl: "",
      homeDistrict: {
        provinceId: "10",
        provinceNameTh: "กรุงเทพมหานคร",
        provinceNameEn: "Bangkok",
        districtId: "1023",
        districtNameTh: "บางมด",
        districtNameEn: "Bang Mod",
      },
      bio: "",
      createdAt: Timestamp.now(),
      tradesCount: 0,
      totalCo2Saved: 0,
      totalWasteDiverted: 0,
    };
    await db.doc("users/alice").set({ ...baseUser, displayName: "Alice" });
    await db.doc("users/bob").set({ ...baseUser, displayName: "Bob" });

    const token = signToken({ displayerUserId: "alice" });
    const tokenHash = sha256(token);

    const result = await handleValidateQRToken(
      "bob",
      { token },
      () => TEST_SECRET,
    );

    expect(result.success).toBe(true);
    expect(typeof result.tradeId).toBe("string");
    expect(result.tradeId.length).toBeGreaterThan(0);

    // Exactly one trade doc was written.
    const trades = await db.collection("trades").get();
    expect(trades.size).toBe(1);

    const trade = (
      await db.doc(`trades/${result.tradeId}`).get()
    ).data() as TradeDoc;
    expect(trade.matchId).toBe("m1");
    expect(trade.jwtTokenHash).toBe(tokenHash);
    expect(trade.itemsExchanged).toEqual({ fromA: "itemX", fromB: "itemY" });
    // 1.2 * 6 evaluates to 7.199999999999999 in IEEE-754; the worked
    // example states 7.2. Use toBeCloseTo so the test reflects how the
    // value is read at any practical UI precision.
    expect(trade.impact.userAGains.userId).toBe("alice");
    expect(trade.impact.userAGains.co2Saved).toBeCloseTo(7.2, 10);
    expect(trade.impact.userAGains.wasteDiverted).toBeCloseTo(0.6, 10);
    expect(trade.impact.userBGains.userId).toBe("bob");
    expect(trade.impact.userBGains.co2Saved).toBeCloseTo(15, 10);
    expect(trade.impact.userBGains.wasteDiverted).toBeCloseTo(1.2, 10);

    // Both items flipped to 'traded'.
    const itemX = (await db.doc("items/itemX").get()).data();
    const itemY = (await db.doc("items/itemY").get()).data();
    expect(itemX?.status).toBe("traded");
    expect(itemY?.status).toBe("traded");

    // Match flipped to 'completed' with a completedAt timestamp.
    const match = (await db.doc("matches/m1").get()).data();
    expect(match?.status).toBe("completed");
    expect(match?.completedAt).toBeInstanceOf(Timestamp);

    // All six counter fields incremented.
    const alice = (await db.doc("users/alice").get()).data();
    const bob = (await db.doc("users/bob").get()).data();
    expect(alice?.tradesCount).toBe(1);
    expect(alice?.totalCo2Saved).toBeCloseTo(7.2, 10);
    expect(alice?.totalWasteDiverted).toBeCloseTo(0.6, 10);
    expect(bob?.tradesCount).toBe(1);
    expect(bob?.totalCo2Saved).toBeCloseTo(15, 10);
    expect(bob?.totalWasteDiverted).toBeCloseTo(1.2, 10);
  });
});
