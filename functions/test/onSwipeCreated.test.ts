/**
 * WBS 8.3 — Mutual Swipe Detection tests.
 *
 * Verifies the four Testing criteria from the WBS 8.3 entry:
 *   1. A right-swipes B, then B right-swipes A → exactly one /matches/ doc.
 *   2. A right-swipes B with no reciprocal swipe → no /matches/ doc.
 *   3. A and B both right-swipe but one declared item has status 'traded'
 *      → no /matches/ doc (defensive item-status check).
 *   4. Rapid double-fire of the trigger (idempotency) → still exactly one
 *      /matches/ doc.
 *
 * Plus an Acceptance-criterion check that the created doc carries
 * `participants: [userAId, userBId]` for the security-rules query that
 * gates /matches/ reads (WBS 3.2).
 *
 * These tests talk directly to the Firestore emulator via the Admin SDK
 * (running because `npm test` wraps Jest in `firebase emulators:exec --only
 * firestore,storage --project demo-ecoswap`). The trigger handler is
 * imported as a plain function (`handleSwipeCreated`) so we can call it
 * synchronously without standing up the Cloud Functions framework — this is
 * the same pattern the v2 firebase-functions-test docs recommend for unit
 * tests of background triggers.
 */

import { initializeApp, getApps, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import { handleSwipeCreated } from "../src/onSwipeCreated";
import type { SwipeDoc, ItemDoc } from "../src/types";

const PROJECT_ID = "demo-ecoswap";

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

/**
 * Reset all collections this suite touches between tests. Done by listing
 * docs and deleting them — the emulator REST `clearFirestore` is also an
 * option but this works with just the Admin SDK.
 */
async function resetFirestore(): Promise<void> {
  const db = getFirestore();
  for (const coll of ["swipes", "matches", "items"]) {
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

/** Build a valid /swipes/{id} doc. */
function swipeDoc(
  swiperId: string,
  targetUserId: string,
  desiredItemId: string,
  direction: SwipeDoc["direction"] = "right",
): SwipeDoc {
  return {
    swiperId,
    targetUserId,
    desiredItemId,
    direction,
    createdAt: Timestamp.now(),
  };
}

/** Seed the typical two-user, two-item, two-swipe fixture used in most tests. */
async function seedMutualSwipeFixture(opts: {
  /** Override A's declared item's status. */
  itemXStatus?: ItemDoc["status"];
  /** Override B's declared item's status. */
  itemYStatus?: ItemDoc["status"];
}): Promise<{
  aSwipe: SwipeDoc;
  bSwipe: SwipeDoc;
}> {
  const db = getFirestore();
  // itemX is owned by B, declared (desired) by A.
  // itemY is owned by A, declared (desired) by B.
  await db.doc("items/itemX").set(itemDoc("bob", { status: opts.itemXStatus ?? "active" }));
  await db.doc("items/itemY").set(itemDoc("alice", { status: opts.itemYStatus ?? "active" }));

  const aSwipe = swipeDoc("alice", "bob", "itemX");
  const bSwipe = swipeDoc("bob", "alice", "itemY");
  // Seed the reciprocal swipe first — the trigger fires on the "second" one,
  // which is `aSwipe` in our scenario. (Alice swipes after Bob had already
  // swiped earlier.)
  await db.collection("swipes").add(bSwipe);
  return { aSwipe, bSwipe };
}

describe("WBS 8.3 — onSwipeCreated", () => {
  test("A right-swipes B and B right-swipes A → exactly one /matches/ doc", async () => {
    const { aSwipe } = await seedMutualSwipeFixture({});

    // Simulate the trigger firing on Alice's freshly-created swipe.
    await handleSwipeCreated(aSwipe);

    const db = getFirestore();
    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(1);

    const match = matches.docs[0].data();
    expect(match.userAId).toBe("alice");
    expect(match.userBId).toBe("bob");
    expect(match.userAWantsItemId).toBe("itemX");
    expect(match.userBWantsItemId).toBe("itemY");
    expect(match.status).toBe("active");
    // participants array gates /matches/ reads in WBS 3.2 security rules.
    expect(match.participants).toEqual(
      expect.arrayContaining(["alice", "bob"]),
    );
    expect(match.completedAt).toBeNull();
    // Document id is the sorted-and-joined uid pair.
    expect(matches.docs[0].id).toBe("alice_bob");
  });

  test("A right-swipes B with no reciprocal swipe → no /matches/ doc", async () => {
    const db = getFirestore();
    // Only itemX exists (B's item). No reciprocal swipe from B.
    await db.doc("items/itemX").set(itemDoc("bob"));

    await handleSwipeCreated(swipeDoc("alice", "bob", "itemX"));

    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(0);
  });

  test("left-swipe never creates a match", async () => {
    const { aSwipe } = await seedMutualSwipeFixture({});
    // Force the new swipe to be a left-swipe — should be a no-op even with
    // a reciprocal right-swipe already in the collection.
    aSwipe.direction = "left";

    await handleSwipeCreated(aSwipe);

    const db = getFirestore();
    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(0);
  });

  test("declared item has status 'traded' → no /matches/ doc", async () => {
    // B's declared item (itemY, what B wants from A) has already been traded
    // away by Alice in some other match. The defensive check should bail.
    const { aSwipe } = await seedMutualSwipeFixture({ itemYStatus: "traded" });

    await handleSwipeCreated(aSwipe);

    const db = getFirestore();
    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(0);
  });

  test("A's declared item is 'traded' → no /matches/ doc", async () => {
    // Symmetric: A wanted itemX (owned by B), but B has since traded it.
    const { aSwipe } = await seedMutualSwipeFixture({ itemXStatus: "traded" });

    await handleSwipeCreated(aSwipe);

    const db = getFirestore();
    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(0);
  });

  test("rapid double-fire of the trigger is idempotent (exactly one match)", async () => {
    const { aSwipe } = await seedMutualSwipeFixture({});

    // Fire the handler twice concurrently — simulates the trigger
    // double-delivering, or two near-simultaneous swipe writes (which can
    // happen if a client retries on network blip). Both invocations target
    // the same matchId because it's derived from the sorted uid pair.
    await Promise.all([
      handleSwipeCreated(aSwipe),
      handleSwipeCreated(aSwipe),
    ]);

    const db = getFirestore();
    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(1);
  });

  test("undefined swipe payload is a safe no-op", async () => {
    // Defensive: event.data?.data() can be undefined if the document was
    // deleted between trigger fire and read. Handler should not throw.
    await expect(handleSwipeCreated(undefined)).resolves.toBeUndefined();

    const db = getFirestore();
    const matches = await db.collection("matches").get();
    expect(matches.size).toBe(0);
  });
});
