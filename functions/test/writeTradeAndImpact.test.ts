/**
 * WBS 10.6 — writeTradeAndImpact tests.
 *
 * Covers the four Testing criteria from the WBS 10.6 entry:
 *
 *   1. Unit (worked example):   the 11.1 worked example
 *      (Ploy 0.6kg clothing ⇄ Fah 1.2kg kitchenware) produces
 *      aCo2=7.2, aWaste=0.6, bCo2=15, bWaste=1.2.
 *   2. Unit (weight fallback):  weight: null falls back to
 *      TYPICAL_WEIGHT[category].
 *   3. Unit (all 7 categories): every category produces non-NaN,
 *      non-negative co2 and waste.
 *   4. Integration:             a successful invocation flips both items
 *      to 'traded' and increments all 6 counter fields.
 *
 * The mapping from the worked example to (A, B):
 *   - User A = "ploy"  gives    her denim jacket   (clothing,    0.6 kg)
 *   - User B = "fah"   gives    her electric kettle (kitchenware, 1.2 kg)
 * which makes:
 *   - aGives = ploy's jacket    → resolved from match.userBWantsItemId
 *   - bGives = fah's kettle     → resolved from match.userAWantsItemId
 *
 * The helper is exercised through a real Firestore transaction against the
 * local emulator (the same harness used by validateQRToken.test.ts and
 * issueQRToken.test.ts). That gives us a real Transaction object — we don't
 * have to mock the API surface — and lets us read back the post-commit
 * documents to assert the writes.
 */

import { initializeApp, getApps, deleteApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

import { writeTradeAndImpact } from "../src/writeTradeAndImpact";
import { CO2_INTENSITY, TYPICAL_WEIGHT } from "../src/constants/impact";
import type { Category } from "../src/constants/impact";
import type { ItemDoc, MatchDoc, UserDoc, TradeDoc } from "../src/types";

const PROJECT_ID = "demo-ecoswap";

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

/** Build a valid /matches/{id} doc. */
function matchDoc(overrides: Partial<MatchDoc> = {}): MatchDoc {
  return {
    userAId: "ploy",
    userBId: "fah",
    userAWantsItemId: "kettle",   // A wants → B (fah) gives
    userBWantsItemId: "jacket",   // B wants → A (ploy) gives
    status: "active",
    participants: ["ploy", "fah"],
    createdAt: Timestamp.now(),
    completedAt: null,
    ...overrides,
  };
}

/** Build a /users/{uid} doc with zeroed counters. */
function userDoc(displayName: string, overrides: Partial<UserDoc> = {}): UserDoc {
  return {
    email: `${displayName}@example.com`,
    displayName,
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
    ...overrides,
  };
}

/**
 * Run writeTradeAndImpact inside a real Firestore transaction. The match
 * doc must already be seeded in /matches/{matchId}; we read it inside the
 * tx to satisfy the reads-before-writes contract that the helper assumes
 * its caller has held.
 */
async function runHelper(
  matchId: string,
  tokenHash: string,
): Promise<string> {
  const db = getFirestore();
  return await db.runTransaction(async (tx) => {
    const matchSnap = await tx.get(db.doc(`matches/${matchId}`));
    const m = matchSnap.data() as MatchDoc;
    return await writeTradeAndImpact(tx, m, matchId, tokenHash);
  });
}

describe("WBS 10.6 — writeTradeAndImpact", () => {
  // -------------------------------------------------------------------------
  // 1. Worked example (WBS 11.1 / WBS 10.6 Testing section).
  //
  //   Ploy = A; her denim jacket (clothing, 0.6 kg) is what she gives.
  //   Fah  = B; her electric kettle (kitchenware, 1.2 kg) is what she gives.
  //
  //   Per attribution rules:
  //     - A receives kettle (kitchenware, 1.2 kg) → aCo2 = 1.2 * 6  = 7.2
  //     - A gives jacket (0.6 kg)                  → aWaste = 0.6
  //     - B receives jacket (clothing, 0.6 kg)     → bCo2 = 0.6 * 25 = 15
  //     - B gives kettle (1.2 kg)                  → bWaste = 1.2
  // -------------------------------------------------------------------------
  test("worked example produces aCo2=7.2 aWaste=0.6 bCo2=15 bWaste=1.2", async () => {
    const db = getFirestore();

    await db.doc("items/jacket").set(itemDoc("ploy", {
      name: "Denim Jacket",
      category: "clothing",
      weight: 0.6,
    }));
    await db.doc("items/kettle").set(itemDoc("fah", {
      name: "Electric Kettle",
      category: "kitchenware",
      weight: 1.2,
    }));
    await db.doc("users/ploy").set(userDoc("Ploy"));
    await db.doc("users/fah").set(userDoc("Fah"));
    await db.doc("matches/m1").set(matchDoc());

    const tradeId = await runHelper("m1", "hash-worked-example");

    const tradeSnap = await db.doc(`trades/${tradeId}`).get();
    const trade = tradeSnap.data() as TradeDoc;

    expect(trade.matchId).toBe("m1");
    expect(trade.jwtTokenHash).toBe("hash-worked-example");
    expect(trade.itemsExchanged).toEqual({
      fromA: "jacket", // Ploy's jacket now in Fah's hands
      fromB: "kettle", // Fah's kettle now in Ploy's hands
    });

    // Use toBeCloseTo for the CO2 figure: 1.2 * 6 evaluates to
    // 7.199999999999999 in IEEE-754, not the literal 7.2 the worked
    // example states. The acceptance criterion is "matches the worked
    // example" — and 7.199999999999999 rounds to 7.2 at any practical
    // display precision (the UI renders one decimal place).
    expect(trade.impact.userAGains.userId).toBe("ploy");
    expect(trade.impact.userAGains.co2Saved).toBeCloseTo(7.2, 10);
    expect(trade.impact.userAGains.wasteDiverted).toBeCloseTo(0.6, 10);

    expect(trade.impact.userBGains.userId).toBe("fah");
    expect(trade.impact.userBGains.co2Saved).toBeCloseTo(15, 10);
    expect(trade.impact.userBGains.wasteDiverted).toBeCloseTo(1.2, 10);
  });

  // -------------------------------------------------------------------------
  // 2. Weight fallback.
  //
  // When ItemDoc.weight is null, the helper must substitute
  // TYPICAL_WEIGHT[category]. We use 'books' on both sides to keep the
  // math simple and the assertion exact:
  //   books typical weight = 0.4 kg, intensity = 1.5 kg CO2/kg
  //   aCo2 = wB * iB = 0.4 * 1.5 = 0.6
  //   bCo2 = wA * iA = 0.4 * 1.5 = 0.6
  // -------------------------------------------------------------------------
  test("weight: null falls back to TYPICAL_WEIGHT[category]", async () => {
    const db = getFirestore();

    await db.doc("items/jacket").set(itemDoc("ploy", {
      name: "Mystery Paperback",
      category: "books",
      weight: null,
    }));
    await db.doc("items/kettle").set(itemDoc("fah", {
      name: "Cookbook",
      category: "books",
      weight: null,
    }));
    await db.doc("users/ploy").set(userDoc("Ploy"));
    await db.doc("users/fah").set(userDoc("Fah"));
    await db.doc("matches/m1").set(matchDoc());

    const tradeId = await runHelper("m1", "hash-fallback");
    const trade = (await db.doc(`trades/${tradeId}`).get()).data() as TradeDoc;

    const expectedCo2 = TYPICAL_WEIGHT.books * CO2_INTENSITY.books;
    const expectedWaste = TYPICAL_WEIGHT.books;

    expect(trade.impact.userAGains.co2Saved).toBeCloseTo(expectedCo2, 10);
    expect(trade.impact.userAGains.wasteDiverted).toBeCloseTo(expectedWaste, 10);
    expect(trade.impact.userBGains.co2Saved).toBeCloseTo(expectedCo2, 10);
    expect(trade.impact.userBGains.wasteDiverted).toBeCloseTo(expectedWaste, 10);
  });

  // -------------------------------------------------------------------------
  // 3. All 7 categories produce non-NaN, non-negative impact.
  //
  // For each category, exchange two items of the same category with
  // weight=null so we exercise the fallback table for that category.
  // This is a smoke test against silently missing keys (which would
  // produce NaN once multiplied) or sign errors.
  // -------------------------------------------------------------------------
  test.each<Category>([
    "clothing",
    "books",
    "kitchenware",
    "household",
    "electronics",
    "furniture",
    "other",
  ])("category %s produces non-NaN non-negative impact", async (category) => {
    const db = getFirestore();

    await db.doc("items/jacket").set(itemDoc("ploy", {
      name: `Item-${category}-A`,
      category,
      weight: null,
    }));
    await db.doc("items/kettle").set(itemDoc("fah", {
      name: `Item-${category}-B`,
      category,
      weight: null,
    }));
    await db.doc("users/ploy").set(userDoc("Ploy"));
    await db.doc("users/fah").set(userDoc("Fah"));
    await db.doc("matches/m1").set(matchDoc());

    const tradeId = await runHelper("m1", `hash-cat-${category}`);
    const trade = (await db.doc(`trades/${tradeId}`).get()).data() as TradeDoc;

    for (const gains of [trade.impact.userAGains, trade.impact.userBGains]) {
      expect(Number.isNaN(gains.co2Saved)).toBe(false);
      expect(Number.isNaN(gains.wasteDiverted)).toBe(false);
      expect(gains.co2Saved).toBeGreaterThanOrEqual(0);
      expect(gains.wasteDiverted).toBeGreaterThanOrEqual(0);
    }
  });

  // -------------------------------------------------------------------------
  // 4. Integration: a successful invocation flips both items to 'traded'
  //    and increments all 6 counter fields. Uses the worked-example fixture
  //    so the post-commit numbers are exact.
  // -------------------------------------------------------------------------
  test("flips both items to 'traded' and increments all 6 counters", async () => {
    const db = getFirestore();

    await db.doc("items/jacket").set(itemDoc("ploy", {
      name: "Denim Jacket",
      category: "clothing",
      weight: 0.6,
    }));
    await db.doc("items/kettle").set(itemDoc("fah", {
      name: "Electric Kettle",
      category: "kitchenware",
      weight: 1.2,
    }));
    // Seed users with non-zero starting counters to prove `increment`
    // adds rather than overwrites.
    await db.doc("users/ploy").set(userDoc("Ploy", {
      tradesCount: 2,
      totalCo2Saved: 100,
      totalWasteDiverted: 4,
    }));
    await db.doc("users/fah").set(userDoc("Fah", {
      tradesCount: 5,
      totalCo2Saved: 50,
      totalWasteDiverted: 2,
    }));
    await db.doc("matches/m1").set(matchDoc());

    const tradeId = await runHelper("m1", "hash-integration");

    // Trade doc exists and is unique.
    const trades = await db.collection("trades").get();
    expect(trades.size).toBe(1);
    expect(trades.docs[0].id).toBe(tradeId);

    // Both items flipped to 'traded'.
    const jacket = (await db.doc("items/jacket").get()).data() as ItemDoc;
    const kettle = (await db.doc("items/kettle").get()).data() as ItemDoc;
    expect(jacket.status).toBe("traded");
    expect(kettle.status).toBe("traded");

    // All 6 counters incremented (3 per user × 2 users).
    const ploy = (await db.doc("users/ploy").get()).data() as UserDoc;
    const fah = (await db.doc("users/fah").get()).data() as UserDoc;

    expect(ploy.tradesCount).toBe(3);          // 2 + 1
    expect(ploy.totalCo2Saved).toBeCloseTo(107.2, 10); // 100 + 7.2
    expect(ploy.totalWasteDiverted).toBeCloseTo(4.6, 10); // 4 + 0.6

    expect(fah.tradesCount).toBe(6);            // 5 + 1
    expect(fah.totalCo2Saved).toBeCloseTo(65, 10);  // 50 + 15
    expect(fah.totalWasteDiverted).toBeCloseTo(3.2, 10); // 2 + 1.2
  });

  // -------------------------------------------------------------------------
  // Bonus: serverTimestamp resolves to a real Timestamp on read.
  // Belt-and-braces — guards against a future refactor that accidentally
  // writes `Date.now()` or a string here.
  // -------------------------------------------------------------------------
  test("completedAt resolves to a Timestamp after commit", async () => {
    const db = getFirestore();
    await db.doc("items/jacket").set(itemDoc("ploy", {
      category: "clothing",
      weight: 0.6,
    }));
    await db.doc("items/kettle").set(itemDoc("fah", {
      category: "kitchenware",
      weight: 1.2,
    }));
    await db.doc("users/ploy").set(userDoc("Ploy"));
    await db.doc("users/fah").set(userDoc("Fah"));
    await db.doc("matches/m1").set(matchDoc());

    const tradeId = await runHelper("m1", "hash-timestamp");
    const trade = (await db.doc(`trades/${tradeId}`).get()).data() as TradeDoc;
    expect(trade.completedAt).toBeInstanceOf(Timestamp);
  });
});
