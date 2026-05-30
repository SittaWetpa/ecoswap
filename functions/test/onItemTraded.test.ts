/**
 * WBS 8.5 — Hard-Cancel Pending Swipes When Item Traded tests.
 *
 * Verifies the Testing criteria from the WBS 8.5 entry:
 *   1. Trade completes; the completing match is NOT cancelled.
 *   2. Trade completes; a separate pending match referencing the same
 *      item IS cancelled.
 *   3. Trade completes; pending right-swipes referencing the item are
 *      deleted.
 *   4. The OTHER party of a cancelled match gets a notification entry.
 *
 * Plus an Acceptance-criterion check for the active->traded transition
 * guard: the handler must NOT re-fire if the item was already traded
 * before the update (e.g. a later edit to the doc).
 *
 * These tests talk directly to the Firestore emulator via the Admin SDK
 * (running because `npm test` wraps Jest in `firebase emulators:exec --only
 * firestore,storage --project demo-ecoswap`). The trigger handler is
 * imported as a plain function (`handleItemTraded`) so we can drive it
 * synchronously with synthetic before/after payloads — same pattern as
 * WBS 8.3's `handleSwipeCreated` tests.
 */

import { initializeApp, getApps, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import { handleItemTraded } from "../src/onItemTraded";
import type {
  ItemDoc,
  MatchDoc,
  SwipeDoc,
  TradeDoc,
} from "../src/types";

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
 * Reset all collections this suite touches between tests. We also clear
 * notifications subcollections under /users — emulator stores them under
 * their parent docs which we don't otherwise touch, so we sweep them
 * explicitly.
 */
async function resetFirestore(): Promise<void> {
  const db = getFirestore();
  for (const coll of ["swipes", "matches", "items", "trades"]) {
    const snap = await db.collection(coll).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
  // Notifications are subcollections of /users — list user docs and clear.
  const users = await db.collection("users").listDocuments();
  for (const userRef of users) {
    const notifs = await userRef.collection("notifications").get();
    await Promise.all(notifs.docs.map((d) => d.ref.delete()));
  }
}

beforeEach(async () => {
  await resetFirestore();
});

/** Build a valid /items/{id} doc, defaulting to status 'active'. */
function itemDoc(
  ownerId: string,
  overrides: Partial<ItemDoc> = {},
): ItemDoc {
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

/** Build a valid /matches/{id} doc, defaulting to status 'active'. */
function matchDoc(
  userAId: string,
  userBId: string,
  userAWantsItemId: string,
  userBWantsItemId: string,
  overrides: Partial<MatchDoc> = {},
): MatchDoc {
  return {
    userAId,
    userBId,
    userAWantsItemId,
    userBWantsItemId,
    status: "active",
    participants: [userAId, userBId],
    createdAt: Timestamp.now(),
    completedAt: null,
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

/** Build a valid /trades/{id} doc. */
function tradeDoc(
  matchId: string,
  fromA: string,
  fromB: string,
): TradeDoc {
  return {
    matchId,
    completedAt: Timestamp.now(),
    jwtTokenHash: "deadbeef",
    impact: {
      userAGains: { userId: "alice", co2Saved: 1, wasteDiverted: 1 },
      userBGains: { userId: "bob", co2Saved: 1, wasteDiverted: 1 },
    },
    itemsExchanged: { fromA, fromB },
  };
}

describe("WBS 8.5 — onItemTraded", () => {
  test("completing match is NOT cancelled when the item it caused trades", async () => {
    // Setup: alice's itemY is the one being traded in match alice_bob.
    // /trades/T1 references it via itemsExchanged.fromA = itemY.
    // After the trade, alice's itemY has flipped to status='traded'.
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { name: "Denim Jacket" });
    const afterItem: ItemDoc = { ...beforeItem, status: "traded" };
    // The /matches/ doc is already 'completed' at this point (10.2 flips
    // it to completed inside the same transaction as the item flip), but
    // for the purposes of testing the handler's skip logic, the important
    // invariant is that it must not be downgraded to 'cancelled'. We seed
    // it as 'completed' to mirror the real post-transaction state.
    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    const match = await db.doc("matches/alice_bob").get();
    expect(match.data()?.status).toBe("completed");
    // No notification should have been written to either party of the
    // completing match.
    const aliceNotifs = await db
      .collection("users")
      .doc("alice")
      .collection("notifications")
      .get();
    const bobNotifs = await db
      .collection("users")
      .doc("bob")
      .collection("notifications")
      .get();
    expect(aliceNotifs.size).toBe(0);
    expect(bobNotifs.size).toBe(0);
  });

  test("a separate pending match referencing the same item IS cancelled", async () => {
    // Setup: alice's itemY is wanted by both bob (in the completing match
    // alice_bob) AND carol (in a separate pending match alice_carol that
    // hasn't progressed to QR yet). When itemY trades to bob, the
    // alice_carol match must be cancelled.
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { name: "Denim Jacket" });
    const afterItem: ItemDoc = { ...beforeItem, status: "traded" };

    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    await db
      .doc("matches/alice_carol")
      .set(matchDoc("alice", "carol", "itemZ", "itemY"));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    // The completing match is untouched.
    const completingMatch = await db.doc("matches/alice_bob").get();
    expect(completingMatch.data()?.status).toBe("completed");

    // The pending match is cancelled.
    const pendingMatch = await db.doc("matches/alice_carol").get();
    expect(pendingMatch.data()?.status).toBe("cancelled");
  });

  test("pending right-swipes referencing the traded item are deleted", async () => {
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { name: "Denim Jacket" });
    const afterItem: ItemDoc = { ...beforeItem, status: "traded" };

    // Three pending right-swipes from different users all desire itemY,
    // plus one LEFT-swipe (which must NOT be touched) and one right-swipe
    // for a different item (must NOT be touched either).
    await db.collection("swipes").doc("s1").set(swipeDoc("dan", "alice", "itemY"));
    await db.collection("swipes").doc("s2").set(swipeDoc("eve", "alice", "itemY"));
    await db.collection("swipes").doc("s3").set(swipeDoc("fay", "alice", "itemY"));
    await db
      .collection("swipes")
      .doc("s4")
      .set(swipeDoc("gus", "alice", "itemY", "left"));
    await db.collection("swipes").doc("s5").set(swipeDoc("hal", "alice", "itemZ"));

    // Seed an empty completing trade so the handler has something to look
    // up but no skip-set match against pending swipes (swipes are global).
    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    // Right-swipes for itemY are gone; left-swipe and unrelated right-swipe
    // remain.
    expect((await db.collection("swipes").doc("s1").get()).exists).toBe(false);
    expect((await db.collection("swipes").doc("s2").get()).exists).toBe(false);
    expect((await db.collection("swipes").doc("s3").get()).exists).toBe(false);
    expect((await db.collection("swipes").doc("s4").get()).exists).toBe(true);
    expect((await db.collection("swipes").doc("s5").get()).exists).toBe(true);
  });

  test("the two mutual swipes that formed the completing match are swept (enables post-trade re-discovery, product decision #3)", async () => {
    // Regression guard for product decision #3: after a completed trade, the
    // two swappers must be able to rediscover each other in Discover. The
    // feed excludes already-swiped users, so re-discovery depends on the
    // match-forming swipe docs being deleted when the trade completes.
    //
    // Match alice_bob: alice (A) wanted bob's itemX; bob (B) wanted alice's
    // itemY. So the forming swipes are alice->bob (desiredItemId itemX) and
    // bob->alice (desiredItemId itemY). The trade flips BOTH items to
    // 'traded', firing onItemTraded once per item; each fire sweeps the
    // swipe whose desiredItemId is that item.
    const db = getFirestore();

    await db.collection("swipes").doc("sAB").set(swipeDoc("alice", "bob", "itemX"));
    await db.collection("swipes").doc("sBA").set(swipeDoc("bob", "alice", "itemY"));
    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    // itemY (alice's) trades -> sweeps bob's swipe (desiredItemId itemY).
    const itemY = itemDoc("alice", { name: "Denim Jacket" });
    await handleItemTraded(itemY, { ...itemY, status: "traded" }, "itemY");
    // itemX (bob's) trades -> sweeps alice's swipe (desiredItemId itemX).
    const itemX = itemDoc("bob", { name: "Wool Scarf" });
    await handleItemTraded(itemX, { ...itemX, status: "traded" }, "itemX");

    // Both forming swipes are gone -> neither user excludes the other in the
    // feed anymore, so they can rematch if they still have active items.
    expect((await db.collection("swipes").doc("sAB").get()).exists).toBe(false);
    expect((await db.collection("swipes").doc("sBA").get()).exists).toBe(false);
  });

  test("the OTHER party of a cancelled match gets a notification", async () => {
    // carol's match referenced alice's itemY (carol wanted it). When itemY
    // trades to bob, carol's match is cancelled and CAROL — not alice — is
    // the one who gets the 'item_unavailable' notification.
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { name: "Denim Jacket" });
    const afterItem: ItemDoc = { ...beforeItem, status: "traded" };

    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    // In match alice_carol, userA=alice, userB=carol. carol wants itemY,
    // which lives on userBWantsItemId (B = carol, so... no wait — schema
    // says userBWantsItemId is what B picked of A's items, so carol picked
    // alice's itemY).
    await db
      .doc("matches/alice_carol")
      .set(matchDoc("alice", "carol", "itemZ", "itemY"));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    // The "other party" — the one losing out — is carol (userB of the
    // cancelled match, because userBWantsItemId === itemY).
    const carolNotifs = await db
      .collection("users")
      .doc("carol")
      .collection("notifications")
      .get();
    expect(carolNotifs.size).toBe(1);
    const notif = carolNotifs.docs[0].data();
    expect(notif.type).toBe("item_unavailable");
    expect(notif.itemId).toBe("itemY");
    expect(notif.similarSearchQuery).toBe("Denim Jacket");
    expect(notif.createdAt).toBeDefined();

    // alice (the owner of the item, who successfully traded it away) gets
    // NO notification — she was party to the completing trade.
    const aliceNotifs = await db
      .collection("users")
      .doc("alice")
      .collection("notifications")
      .get();
    expect(aliceNotifs.size).toBe(0);
  });

  test("notification recipient is userA when userAWantsItemId is the traded item", async () => {
    // Symmetric coverage: in a match where the OTHER party wanted the
    // traded item is on the A side. Specifically, in match dan_alice
    // (userA=dan, userB=alice), dan wanted alice's itemY (userAWantsItemId
    // = itemY). When alice trades itemY to bob, dan must be the one
    // notified.
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { name: "Denim Jacket" });
    const afterItem: ItemDoc = { ...beforeItem, status: "traded" };

    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    await db
      .doc("matches/dan_alice")
      .set(matchDoc("dan", "alice", "itemY", "itemW"));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    // The cancelled match's other-party is dan (userA, because
    // userAWantsItemId === itemY).
    const danNotifs = await db
      .collection("users")
      .doc("dan")
      .collection("notifications")
      .get();
    expect(danNotifs.size).toBe(1);
    expect(danNotifs.docs[0].data().type).toBe("item_unavailable");
    expect(danNotifs.docs[0].data().itemId).toBe("itemY");

    const aliceNotifs = await db
      .collection("users")
      .doc("alice")
      .collection("notifications")
      .get();
    expect(aliceNotifs.size).toBe(0);
  });

  test("no-op when before.status is not 'active' (guard against re-fire)", async () => {
    // If the doc was already 'traded' before the update — e.g. an admin
    // edited an unrelated field on the now-traded item — the handler must
    // be a no-op. Without this guard, every subsequent edit would
    // duplicate notifications and re-delete (no-op) swipes.
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { status: "traded" });
    const afterItem = itemDoc("alice", { status: "traded", name: "Edited" });

    // Seed a pending match and a pending swipe that WOULD be swept if the
    // guard failed.
    await db
      .doc("matches/alice_carol")
      .set(matchDoc("alice", "carol", "itemZ", "itemY"));
    await db
      .collection("swipes")
      .doc("s1")
      .set(swipeDoc("dan", "alice", "itemY"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    // Match still active, swipe still present, no notifications written.
    const match = await db.doc("matches/alice_carol").get();
    expect(match.data()?.status).toBe("active");
    expect((await db.collection("swipes").doc("s1").get()).exists).toBe(true);
    const carolNotifs = await db
      .collection("users")
      .doc("carol")
      .collection("notifications")
      .get();
    expect(carolNotifs.size).toBe(0);
  });

  test("no-op when after.status is not 'traded' (guard against unrelated updates)", async () => {
    // If after.status is 'deleted' or anything other than 'traded', the
    // sweep is not appropriate. Belt-and-braces guard on top of the
    // before-status check.
    const beforeItem = itemDoc("alice", { status: "active" });
    const afterItem = itemDoc("alice", { status: "deleted" });

    const db = getFirestore();
    await db
      .doc("matches/alice_carol")
      .set(matchDoc("alice", "carol", "itemZ", "itemY"));
    await db
      .collection("swipes")
      .doc("s1")
      .set(swipeDoc("dan", "alice", "itemY"));

    await handleItemTraded(beforeItem, afterItem, "itemY");

    const match = await db.doc("matches/alice_carol").get();
    expect(match.data()?.status).toBe("active");
    expect((await db.collection("swipes").doc("s1").get()).exists).toBe(true);
  });

  test("no /trades/ or /users/ counter-field writes from this handler", async () => {
    // Locked decision: WBS 10.6 is the ONLY writer of /trades/ and the
    // counter fields on /users/. This handler must not touch them.
    const db = getFirestore();
    const beforeItem = itemDoc("alice", { name: "Denim Jacket" });
    const afterItem: ItemDoc = { ...beforeItem, status: "traded" };

    await db.doc("users/alice").set({
      tradesCount: 7,
      totalCo2Saved: 100,
      totalWasteDiverted: 50,
    });
    await db.doc("users/carol").set({
      tradesCount: 3,
      totalCo2Saved: 20,
      totalWasteDiverted: 10,
    });
    await db
      .doc("matches/alice_bob")
      .set(matchDoc("alice", "bob", "itemX", "itemY", { status: "completed" }));
    await db
      .doc("matches/alice_carol")
      .set(matchDoc("alice", "carol", "itemZ", "itemY"));
    await db
      .collection("trades")
      .doc("T1")
      .set(tradeDoc("alice_bob", "itemY", "itemX"));

    const tradesBefore = await db.collection("trades").get();
    const tradesBeforeIds = tradesBefore.docs.map((d) => d.id).sort();

    await handleItemTraded(beforeItem, afterItem, "itemY");

    // No new /trades/ docs.
    const tradesAfter = await db.collection("trades").get();
    expect(tradesAfter.docs.map((d) => d.id).sort()).toEqual(tradesBeforeIds);

    // Counter fields untouched on both participating users.
    const alice = await db.doc("users/alice").get();
    expect(alice.data()).toMatchObject({
      tradesCount: 7,
      totalCo2Saved: 100,
      totalWasteDiverted: 50,
    });
    const carol = await db.doc("users/carol").get();
    expect(carol.data()).toMatchObject({
      tradesCount: 3,
      totalCo2Saved: 20,
      totalWasteDiverted: 10,
    });
  });

  test("undefined before or after payload is a safe no-op", async () => {
    // Defensive: event.data?.before/after.data() can be undefined if the
    // doc was deleted between trigger fire and read. Handler should not
    // throw.
    await expect(
      handleItemTraded(undefined, undefined, "itemY"),
    ).resolves.toBeUndefined();
    await expect(
      handleItemTraded(itemDoc("alice"), undefined, "itemY"),
    ).resolves.toBeUndefined();
    await expect(
      handleItemTraded(undefined, itemDoc("alice", { status: "traded" }), "itemY"),
    ).resolves.toBeUndefined();
  });
});
