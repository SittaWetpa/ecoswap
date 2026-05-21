/**
 * WBS 10.1 — issueQRToken tests.
 *
 * Verifies the five Testing criteria from the WBS 10.1 entry:
 *   1. Caller not in match.participants → permission-denied.
 *   2. Match status === 'completed' → failed-precondition.
 *   3. Declared item status === 'traded' → failed-precondition.
 *   4. Valid call returns a token that decodes with the same secret and
 *      carries the documented payload shape (matchId, displayerUserId, iat,
 *      exp).
 *   5. Token `exp` is exactly `iat + 60` — set both fields explicitly per the
 *      WBS pseudocode rather than via `expiresIn`.
 *
 * The handler talks to the Firestore emulator via the Admin SDK (running
 * because `npm test` wraps Jest in
 *   `firebase emulators:exec --only firestore,storage --project demo-ecoswap`
 * ). We exercise `handleIssueQRToken` directly with a thunk-supplied secret —
 * Secret Manager is not available inside the local Jest process, and the
 * thunk pattern mirrors the v2 callable wrapper without requiring the
 * Functions framework to be running.
 */

import { initializeApp, getApps, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/https";
import * as jwt from "jsonwebtoken";

import { handleIssueQRToken } from "../src/issueQRToken";
import type { MatchDoc, ItemDoc, JwtPayload } from "../src/types";

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
  for (const coll of ["matches", "items"]) {
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
  itemXStatus?: ItemDoc["status"];
  itemYStatus?: ItemDoc["status"];
} = {}): Promise<void> {
  const db = getFirestore();
  await db.doc("items/itemX").set(itemDoc("bob", { status: opts.itemXStatus ?? "active" }));
  await db.doc("items/itemY").set(itemDoc("alice", { status: opts.itemYStatus ?? "active" }));
  await db.doc("matches/m1").set(matchDoc(opts.matchOverrides));
}

/**
 * Helper that asserts the handler throws an HttpsError with a specific code.
 * Plain `.rejects.toThrow(/code/)` would not assert on the structured `code`
 * property of HttpsError.
 */
async function expectHttpsErrorCode(
  promise: Promise<unknown>,
  code: HttpsError["code"],
): Promise<void> {
  await expect(promise).rejects.toMatchObject({ code });
}

describe("WBS 10.1 — issueQRToken", () => {
  test("caller not in match → permission-denied", async () => {
    // Charlie tries to claim a token for alice<->bob's match.
    await seedHappyPathFixture();

    await expectHttpsErrorCode(
      handleIssueQRToken("charlie", { matchId: "m1" }, () => TEST_SECRET),
      "permission-denied",
    );
  });

  test("match status === 'completed' → failed-precondition", async () => {
    await seedHappyPathFixture({
      matchOverrides: { status: "completed", completedAt: Timestamp.now() },
    });

    await expectHttpsErrorCode(
      handleIssueQRToken("alice", { matchId: "m1" }, () => TEST_SECRET),
      "failed-precondition",
    );
  });

  test("declared item status === 'traded' → failed-precondition", async () => {
    // itemX (B's declared item that A wants) was traded away in another flow.
    await seedHappyPathFixture({ itemXStatus: "traded" });

    await expectHttpsErrorCode(
      handleIssueQRToken("alice", { matchId: "m1" }, () => TEST_SECRET),
      "failed-precondition",
    );
  });

  test("valid call returns a token that decodes with the same secret", async () => {
    await seedHappyPathFixture();

    const result = await handleIssueQRToken(
      "alice",
      { matchId: "m1" },
      () => TEST_SECRET,
    );

    expect(typeof result.token).toBe("string");
    expect(typeof result.expiresAt).toBe("number");

    // Decoding with the same secret must succeed and the payload must carry
    // exactly the four documented fields with the right values.
    const decoded = jwt.verify(result.token, TEST_SECRET, {
      algorithms: ["HS256"],
    }) as JwtPayload;

    expect(decoded.matchId).toBe("m1");
    expect(decoded.displayerUserId).toBe("alice");
    expect(typeof decoded.iat).toBe("number");
    expect(typeof decoded.exp).toBe("number");

    // A different secret must NOT verify — proves the signing key is
    // actually being used and not bypassed.
    expect(() =>
      jwt.verify(result.token, "wrong-secret", { algorithms: ["HS256"] }),
    ).toThrow();
  });

  test("token `exp` is exactly `iat + 60`", async () => {
    await seedHappyPathFixture();

    // Pin `now` so the assertion is exact and not flaky across the boundary
    // where Math.floor(Date.now()/1000) ticks. Pass `ignoreExpiration` to
    // jwt.verify because FIXED_NOW is a fixed historical second — without
    // the override the verify call would throw TokenExpiredError before we
    // get to inspect the iat/exp relationship that this test exists to
    // prove.
    const FIXED_NOW = 1_700_000_000;
    const result = await handleIssueQRToken(
      "alice",
      { matchId: "m1" },
      () => TEST_SECRET,
      FIXED_NOW,
    );

    const decoded = jwt.verify(result.token, TEST_SECRET, {
      algorithms: ["HS256"],
      ignoreExpiration: true,
    }) as JwtPayload;

    expect(decoded.iat).toBe(FIXED_NOW);
    expect(decoded.exp).toBe(FIXED_NOW + 60);
    expect(decoded.exp - decoded.iat).toBe(60);
    expect(result.expiresAt).toBe(FIXED_NOW + 60);
  });
});
