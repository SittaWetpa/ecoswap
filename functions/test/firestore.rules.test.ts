/**
 * Firestore security rules tests — WBS 3.2.
 *
 * Verifies the five Testing criteria from the WBS 3.2 entry:
 *   1. Unauthenticated read of /users/{any} → denied
 *   2. User A writes to /users/{B} → denied
 *   3. User A increments own tradesCount → denied (counter fields are
 *      Cloud-Function-only per WBS 10.6)
 *   4. User A creates /items/{x} with ownerId: A → allowed
 *   5. User A creates /items/{x} with ownerId: B → denied
 *
 * Plus additional coverage for the four other Acceptance criteria:
 *   - Authenticated client cannot write to /trades/ directly
 *   - Authenticated client cannot write to /matches/ directly
 *   - Match read restricted to participants
 *   - Item update/delete restricted to owner
 *   - Swipes append-only by swiperId
 *   - Messages writable by match participants, sender-locked, read-receipt
 *     update permitted
 *
 * Run via `npm test`, which wraps Jest inside `firebase emulators:exec
 * --only firestore,storage --project demo-ecoswap`.
 */

import * as fs from "fs";
import * as path from "path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  setLogLevel,
} from "firebase/firestore";

const PROJECT_ID = "demo-ecoswap";
const FIRESTORE_RULES_PATH = path.resolve(
  __dirname,
  "../../firestore.rules",
);

let testEnv: RulesTestEnvironment;

// Silence Firestore client warnings during expected-failure assertions.
beforeAll(async () => {
  setLogLevel("error");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(FIRESTORE_RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/**
 * Build a minimal valid /users/{uid} document body. Counters default to 0;
 * pass a partial override to break any field for a specific test.
 */
function userDocBody(overrides: Record<string, unknown> = {}) {
  return {
    email: "user@example.com",
    displayName: "User",
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
    createdAt: serverTimestamp(),
    tradesCount: 0,
    totalCo2Saved: 0,
    totalWasteDiverted: 0,
    ...overrides,
  };
}

/** Build a minimal valid /items/{itemId} document body. */
function itemDocBody(ownerId: string, overrides: Record<string, unknown> = {}) {
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
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

/** Seed a document bypassing security rules (admin path). */
async function seed(
  pathStr: string,
  data: Record<string, unknown>,
): Promise<void> {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), pathStr), data);
  });
}

// ---------------------------------------------------------------------------
// /users/{uid}
// ---------------------------------------------------------------------------

describe("firestore rules — /users/{uid}", () => {
  test("unauthenticated read of /users/{any} is denied (Acceptance #1)", async () => {
    await seed("users/alice", userDocBody());

    const unauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauth, "users/alice")));
  });

  test("authenticated read of any /users/{uid} is allowed", async () => {
    await seed("users/alice", userDocBody());

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(bob, "users/alice")));
  });

  test("user A writes to user B document is denied (Acceptance #2)", async () => {
    await seed("users/bob", userDocBody());

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "users/bob"), { displayName: "Hacked" }),
    );
  });

  test("user A creating their own /users/{A} doc with counters = 0 is allowed", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "users/alice"), userDocBody()),
    );
  });

  test("user A creating their own /users/{A} doc with non-zero counters is denied", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(
        doc(alice, "users/alice"),
        userDocBody({ tradesCount: 5 }),
      ),
    );
  });

  test("user A incrementing own tradesCount is denied (Acceptance #3)", async () => {
    await seed("users/alice", userDocBody());

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "users/alice"), { tradesCount: 1 }),
    );
  });

  test("user A modifying own totalCo2Saved is denied", async () => {
    await seed("users/alice", userDocBody());

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "users/alice"), { totalCo2Saved: 5.0 }),
    );
  });

  test("user A modifying own totalWasteDiverted is denied", async () => {
    await seed("users/alice", userDocBody());

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "users/alice"), { totalWasteDiverted: 1.2 }),
    );
  });

  test("user A updating own bio (not a counter field) is allowed", async () => {
    await seed("users/alice", userDocBody());

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(alice, "users/alice"), { bio: "Updated bio" }),
    );
  });

  test("client cannot delete a /users/ document", async () => {
    await seed("users/alice", userDocBody());

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(deleteDoc(doc(alice, "users/alice")));
  });
});

// ---------------------------------------------------------------------------
// /items/{itemId}
// ---------------------------------------------------------------------------

describe("firestore rules — /items/{itemId}", () => {
  test("user A creates /items/{x} with ownerId: A is allowed (Acceptance #4)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "items/item-1"), itemDocBody("alice")),
    );
  });

  test("user A creates /items/{x} with ownerId: B is denied (Acceptance #5)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "items/item-1"), itemDocBody("bob")),
    );
  });

  test("authenticated user can read any /items/ doc", async () => {
    await seed("items/item-1", itemDocBody("alice"));

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(bob, "items/item-1")));
  });

  test("unauthenticated user cannot read /items/", async () => {
    await seed("items/item-1", itemDocBody("alice"));

    const unauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauth, "items/item-1")));
  });

  test("owner can update their own /items/ doc", async () => {
    await seed("items/item-1", itemDocBody("alice"));

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(alice, "items/item-1"), { name: "Renamed" }),
    );
  });

  test("non-owner cannot update someone else's /items/ doc", async () => {
    await seed("items/item-1", itemDocBody("alice"));

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertFails(
      updateDoc(doc(bob, "items/item-1"), { name: "Stolen" }),
    );
  });

  test("owner can soft-delete (status='deleted') their own item", async () => {
    await seed("items/item-1", itemDocBody("alice"));

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      updateDoc(doc(alice, "items/item-1"), { status: "deleted" }),
    );
  });

  test("non-owner cannot hard-delete someone else's /items/ doc", async () => {
    await seed("items/item-1", itemDocBody("alice"));

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertFails(deleteDoc(doc(bob, "items/item-1")));
  });
});

// ---------------------------------------------------------------------------
// /swipes/{swipeId}
// ---------------------------------------------------------------------------

describe("firestore rules — /swipes/{swipeId}", () => {
  test("user can create a swipe where swiperId == own uid", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "swipes/swipe-1"), {
        swiperId: "alice",
        targetUserId: "bob",
        desiredItemId: "item-1",
        direction: "right",
        createdAt: serverTimestamp(),
      }),
    );
  });

  test("user cannot create a swipe pretending to be someone else", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "swipes/swipe-1"), {
        swiperId: "bob", // not alice
        targetUserId: "carol",
        desiredItemId: "item-1",
        direction: "right",
        createdAt: serverTimestamp(),
      }),
    );
  });

  test("unauthenticated user cannot create swipes", async () => {
    const unauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(unauth, "swipes/swipe-1"), {
        swiperId: "alice",
        targetUserId: "bob",
        desiredItemId: "item-1",
        direction: "right",
        createdAt: serverTimestamp(),
      }),
    );
  });

  test("authenticated user can read any swipe (needed for mutual-swipe detection)", async () => {
    await seed("swipes/swipe-1", {
      swiperId: "alice",
      targetUserId: "bob",
      desiredItemId: "item-1",
      direction: "right",
      createdAt: serverTimestamp(),
    });

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(bob, "swipes/swipe-1")));
  });

  test("swipes are append-only — updates are denied even by the swiper", async () => {
    await seed("swipes/swipe-1", {
      swiperId: "alice",
      targetUserId: "bob",
      desiredItemId: "item-1",
      direction: "right",
      createdAt: serverTimestamp(),
    });

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "swipes/swipe-1"), { direction: "left" }),
    );
  });

  // -------------------------------------------------------------------------
  // WBS 8.1 — desiredItemId validation on right-swipe vs left-swipe
  // -------------------------------------------------------------------------

  test("WBS 8.1 — right-swipe with a non-empty desiredItemId is allowed", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "swipes/swipe-right-1"), {
        swiperId: "alice",
        targetUserId: "bob",
        desiredItemId: "item-1",
        direction: "right",
        createdAt: serverTimestamp(),
      }),
    );
  });

  test("WBS 8.1 — right-swipe with empty desiredItemId is denied", async () => {
    // A client cannot write a right-swipe without declaring an item (F16/F19).
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "swipes/swipe-right-bad"), {
        swiperId: "alice",
        targetUserId: "bob",
        desiredItemId: "", // empty — not allowed for right-swipe
        direction: "right",
        createdAt: serverTimestamp(),
      }),
    );
  });

  test("WBS 8.1 — left-swipe with empty desiredItemId is allowed", async () => {
    // Left-swipes use the empty-string sentinel per the WBS 8.1 spec.
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "swipes/swipe-left-1"), {
        swiperId: "alice",
        targetUserId: "bob",
        desiredItemId: "", // empty sentinel for left-swipe
        direction: "left",
        createdAt: serverTimestamp(),
      }),
    );
  });

  test("WBS 8.1 — left-swipe with a non-empty desiredItemId is denied", async () => {
    // Left-swipes must use the empty sentinel; setting a real item id is invalid.
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "swipes/swipe-left-bad"), {
        swiperId: "alice",
        targetUserId: "bob",
        desiredItemId: "item-1", // must be '' for a left-swipe
        direction: "left",
        createdAt: serverTimestamp(),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// /matches/{matchId}
// ---------------------------------------------------------------------------

describe("firestore rules — /matches/{matchId}", () => {
  const matchBody = {
    userAId: "alice",
    userBId: "bob",
    userAWantsItemId: "item-2",
    userBWantsItemId: "item-1",
    status: "active",
    participants: ["alice", "bob"],
    createdAt: serverTimestamp(),
    completedAt: null,
  };

  test("participant can read their own match", async () => {
    await seed("matches/m1", matchBody);

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(alice, "matches/m1")));
  });

  test("non-participant cannot read a match", async () => {
    await seed("matches/m1", matchBody);

    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(getDoc(doc(carol, "matches/m1")));
  });

  test("client cannot create a /matches/ document (Cloud Function only)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(alice, "matches/m1"), matchBody));
  });

  test("participant cannot update a /matches/ document directly", async () => {
    await seed("matches/m1", matchBody);

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "matches/m1"), { status: "completed" }),
    );
  });

  test("client cannot delete a /matches/ document", async () => {
    await seed("matches/m1", matchBody);

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(deleteDoc(doc(alice, "matches/m1")));
  });
});

// ---------------------------------------------------------------------------
// /matches/{matchId}/messages/{messageId}
// ---------------------------------------------------------------------------

describe("firestore rules — /matches/{matchId}/messages/{messageId}", () => {
  const matchBody = {
    userAId: "alice",
    userBId: "bob",
    userAWantsItemId: "item-2",
    userBWantsItemId: "item-1",
    status: "active",
    participants: ["alice", "bob"],
    createdAt: serverTimestamp(),
    completedAt: null,
  };

  beforeEach(async () => {
    await seed("matches/m1", matchBody);
  });

  test("participant can send a message in their match", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(
      setDoc(doc(alice, "matches/m1/messages/msg-1"), {
        senderId: "alice",
        text: "Hello",
        sentAt: serverTimestamp(),
        readBy: ["alice"],
      }),
    );
  });

  test("participant cannot impersonate another sender", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "matches/m1/messages/msg-1"), {
        senderId: "bob", // impersonation
        text: "Hello",
        sentAt: serverTimestamp(),
        readBy: ["alice"],
      }),
    );
  });

  test("non-participant cannot send messages in someone else's match", async () => {
    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(
      setDoc(doc(carol, "matches/m1/messages/msg-1"), {
        senderId: "carol",
        text: "Hello",
        sentAt: serverTimestamp(),
        readBy: ["carol"],
      }),
    );
  });

  test("participant can read messages in their match", async () => {
    await seed("matches/m1/messages/msg-1", {
      senderId: "alice",
      text: "Hi",
      sentAt: serverTimestamp(),
      readBy: ["alice"],
    });

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(bob, "matches/m1/messages/msg-1")));
  });

  test("non-participant cannot read messages in someone else's match", async () => {
    await seed("matches/m1/messages/msg-1", {
      senderId: "alice",
      text: "Hi",
      sentAt: serverTimestamp(),
      readBy: ["alice"],
    });

    const carol = testEnv.authenticatedContext("carol").firestore();
    await assertFails(getDoc(doc(carol, "matches/m1/messages/msg-1")));
  });

  test("recipient can append own uid to readBy (read receipt, WBS 9.5)", async () => {
    await seed("matches/m1/messages/msg-1", {
      senderId: "alice",
      text: "Hi",
      sentAt: serverTimestamp(),
      readBy: ["alice"],
    });

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(
      updateDoc(doc(bob, "matches/m1/messages/msg-1"), {
        readBy: ["alice", "bob"],
      }),
    );
  });

  test("recipient cannot mutate the text field via the read-receipt update", async () => {
    await seed("matches/m1/messages/msg-1", {
      senderId: "alice",
      text: "Hi",
      sentAt: serverTimestamp(),
      readBy: ["alice"],
    });

    const bob = testEnv.authenticatedContext("bob").firestore();
    await assertFails(
      updateDoc(doc(bob, "matches/m1/messages/msg-1"), {
        readBy: ["alice", "bob"],
        text: "Tampered",
      }),
    );
  });

  test("client cannot delete messages", async () => {
    await seed("matches/m1/messages/msg-1", {
      senderId: "alice",
      text: "Hi",
      sentAt: serverTimestamp(),
      readBy: ["alice"],
    });

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(deleteDoc(doc(alice, "matches/m1/messages/msg-1")));
  });
});

// ---------------------------------------------------------------------------
// /trades/{tradeId}
// ---------------------------------------------------------------------------

describe("firestore rules — /trades/{tradeId}", () => {
  const tradeBody = {
    matchId: "m1",
    completedAt: serverTimestamp(),
    jwtTokenHash: "fakehash",
    impact: {
      userAGains: { userId: "alice", co2Saved: 7.2, wasteDiverted: 0.6 },
      userBGains: { userId: "bob", co2Saved: 15.0, wasteDiverted: 1.2 },
    },
    itemsExchanged: { fromA: "item-1", fromB: "item-2" },
  };

  test("client cannot create a /trades/ doc directly (Acceptance — counter writes are Cloud-Function-only)", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(alice, "trades/t1"), tradeBody));
  });

  test("authenticated client can read a /trades/ doc", async () => {
    await seed("trades/t1", tradeBody);

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(alice, "trades/t1")));
  });

  test("unauthenticated client cannot read /trades/", async () => {
    await seed("trades/t1", tradeBody);

    const unauth = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauth, "trades/t1")));
  });

  test("client cannot update a /trades/ doc", async () => {
    await seed("trades/t1", tradeBody);

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(alice, "trades/t1"), { matchId: "m2" }),
    );
  });

  test("client cannot delete a /trades/ doc", async () => {
    await seed("trades/t1", tradeBody);

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(deleteDoc(doc(alice, "trades/t1")));
  });
});

// ---------------------------------------------------------------------------
// Deny-by-default
// ---------------------------------------------------------------------------

describe("firestore rules — deny-by-default", () => {
  test("authenticated client cannot read a collection that is not declared", async () => {
    await seed("randoms/r1", { foo: "bar" });

    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(alice, "randoms/r1")));
  });

  test("authenticated client cannot write to a collection that is not declared", async () => {
    const alice = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(alice, "randoms/r1"), { foo: "bar" }),
    );
  });
});
