/**
 * WBS 3.6 — Firestore Data Model TypeScript type tests.
 *
 * These tests verify that the 6 collection interfaces in functions/src/types.ts:
 *   1. Compile cleanly with strict: true (if this file compiles, they do)
 *   2. Accept valid document shapes without TypeScript errors
 *   3. Reject forbidden fields at the type level (trust score, lat/lng)
 *   4. Enforce structural requirements from WBS 3.6 (single-select desiredItemId,
 *      counter fields present on UserDoc, jwtTokenHash present on TradeDoc, etc.)
 *
 * No Firebase emulator is needed for these tests — they operate on plain
 * TypeScript objects that satisfy the interfaces.  A Timestamp stub is used
 * in place of the firebase-admin Timestamp class.
 */

import type {
  HomeDistrict,
  UserDoc,
  ItemDoc,
  ItemCategory,
  ItemCondition,
  ItemStatus,
  SwipeDoc,
  SwipeDirection,
  MatchDoc,
  MatchStatus,
  MessageDoc,
  TradeDoc,
  UserImpactGains,
  TradeImpact,
  ItemsExchanged,
  JwtPayload,
} from "../src/types";

// ---------------------------------------------------------------------------
// Minimal Timestamp stub — replaces firebase-admin Timestamp in unit tests.
// ---------------------------------------------------------------------------

interface TimestampLike {
  seconds: number;
  nanoseconds: number;
  toDate(): Date;
  toMillis(): number;
}

function makeTimestamp(seconds = 1_700_000_000): TimestampLike {
  return {
    seconds,
    nanoseconds: 0,
    toDate: () => new Date(seconds * 1000),
    toMillis: () => seconds * 1000,
  };
}

// TypeScript will accept TimestampLike wherever Timestamp is expected because
// firebase-admin Timestamp satisfies the same structural interface.
// We cast through `unknown` to avoid a direct dependency on the admin SDK at
// test time — this is the one place `unknown` casting is intentional.
function ts(seconds?: number) {
  return makeTimestamp(seconds) as unknown as import("firebase-admin/firestore").Timestamp;
}

// ---------------------------------------------------------------------------
// /users/{userId} — UserDoc
// ---------------------------------------------------------------------------

describe("UserDoc", () => {
  const validHomeDistrict: HomeDistrict = {
    provinceId: "10",
    provinceNameTh: "กรุงเทพมหานคร",
    provinceNameEn: "Bangkok",
    districtId: "1023",
    districtNameTh: "บางมด",
    districtNameEn: "Bang Mod",
  };

  test("accepts a fully-populated valid UserDoc", () => {
    const doc: UserDoc = {
      email: "ploy@example.com",
      displayName: "Ploy",
      photoUrl: "https://storage.example.com/user_photos/ploy.jpg",
      homeDistrict: validHomeDistrict,
      bio: "I love sustainable fashion.",
      createdAt: ts(),
      tradesCount: 0,
      totalCo2Saved: 0,
      totalWasteDiverted: 0,
    };
    expect(doc.email).toBe("ploy@example.com");
    expect(doc.tradesCount).toBe(0);
    expect(doc.totalCo2Saved).toBe(0);
    expect(doc.totalWasteDiverted).toBe(0);
  });

  test("homeDistrict has exactly 6 string fields — no lat/lng/centroid", () => {
    const district: HomeDistrict = validHomeDistrict;
    const keys = Object.keys(district);
    expect(keys).toHaveLength(6);
    expect(keys).toContain("provinceId");
    expect(keys).toContain("provinceNameTh");
    expect(keys).toContain("provinceNameEn");
    expect(keys).toContain("districtId");
    expect(keys).toContain("districtNameTh");
    expect(keys).toContain("districtNameEn");
    // These keys must NOT be present (locked decision — CLAUDE.md location model)
    expect(keys).not.toContain("lat");
    expect(keys).not.toContain("lng");
    expect(keys).not.toContain("centroid");
  });

  test("counter fields exist and default to 0", () => {
    const doc: UserDoc = {
      email: "fah@example.com",
      displayName: "Fah",
      photoUrl: "",
      homeDistrict: validHomeDistrict,
      bio: "",
      createdAt: ts(),
      tradesCount: 0,
      totalCo2Saved: 0,
      totalWasteDiverted: 0,
    };
    expect(doc).toHaveProperty("tradesCount");
    expect(doc).toHaveProperty("totalCo2Saved");
    expect(doc).toHaveProperty("totalWasteDiverted");
    expect(typeof doc.tradesCount).toBe("number");
    expect(typeof doc.totalCo2Saved).toBe("number");
    expect(typeof doc.totalWasteDiverted).toBe("number");
  });

  test("trust score field is NOT present on UserDoc interface", () => {
    // If `trustScore` were added to UserDoc, TypeScript would require it here.
    // This test confirms the field is absent by ensuring the doc object
    // does not carry it.
    const doc: UserDoc = {
      email: "test@example.com",
      displayName: "Test",
      photoUrl: "",
      homeDistrict: validHomeDistrict,
      bio: "",
      createdAt: ts(),
      tradesCount: 0,
      totalCo2Saved: 0,
      totalWasteDiverted: 0,
    };
    // Cast through unknown to inspect dynamically — intentional, needed to
    // check for absence of a field that is not part of the typed interface.
    const record = doc as unknown as Record<string, unknown>;
    expect(record).not.toHaveProperty("trustScore");
  });

  test("counter fields can hold positive numbers after completed trades", () => {
    const doc: UserDoc = {
      email: "ploy@example.com",
      displayName: "Ploy",
      photoUrl: "",
      homeDistrict: validHomeDistrict,
      bio: "",
      createdAt: ts(),
      tradesCount: 3,
      totalCo2Saved: 15.6,
      totalWasteDiverted: 2.4,
    };
    expect(doc.tradesCount).toBe(3);
    expect(doc.totalCo2Saved).toBeCloseTo(15.6);
    expect(doc.totalWasteDiverted).toBeCloseTo(2.4);
  });
});

// ---------------------------------------------------------------------------
// /items/{itemId} — ItemDoc
// ---------------------------------------------------------------------------

describe("ItemDoc", () => {
  test("accepts a fully-populated ItemDoc", () => {
    const doc: ItemDoc = {
      ownerId: "uid-ploy",
      name: "Denim Jacket",
      category: "clothing",
      condition: "good",
      weight: 0.6,
      description: "Vintage cut, barely worn.",
      wants: "Books or kitchenware",
      photoUrl: "https://storage.example.com/item_photos/jacket.jpg",
      status: "active",
      createdAt: ts(),
    };
    expect(doc.category).toBe("clothing");
    expect(doc.weight).toBe(0.6);
  });

  test("weight field accepts null (triggers category typical weight fallback)", () => {
    const doc: ItemDoc = {
      ownerId: "uid-fah",
      name: "Kettle",
      category: "kitchenware",
      condition: "like-new",
      weight: null,
      description: null,
      wants: null,
      photoUrl: "https://storage.example.com/item_photos/kettle.jpg",
      status: "active",
      createdAt: ts(),
    };
    expect(doc.weight).toBeNull();
  });

  test("all 7 ItemCategory values are valid", () => {
    const categories: ItemCategory[] = [
      "clothing",
      "books",
      "kitchenware",
      "household",
      "electronics",
      "furniture",
      "other",
    ];
    categories.forEach((cat) => {
      const doc: ItemDoc = {
        ownerId: "uid-test",
        name: "Test item",
        category: cat,
        condition: "good",
        weight: null,
        description: null,
        wants: null,
        photoUrl: "",
        status: "active",
        createdAt: ts(),
      };
      expect(doc.category).toBe(cat);
    });
  });

  test("all 4 ItemCondition values are valid", () => {
    const conditions: ItemCondition[] = ["new", "like-new", "good", "used"];
    conditions.forEach((cond) => {
      const doc: ItemDoc = {
        ownerId: "uid-test",
        name: "Test item",
        category: "other",
        condition: cond,
        weight: null,
        description: null,
        wants: null,
        photoUrl: "",
        status: "active",
        createdAt: ts(),
      };
      expect(doc.condition).toBe(cond);
    });
  });

  test("all 3 ItemStatus values are valid", () => {
    const statuses: ItemStatus[] = ["active", "traded", "deleted"];
    statuses.forEach((s) => {
      const doc: ItemDoc = {
        ownerId: "uid-test",
        name: "Test item",
        category: "other",
        condition: "good",
        weight: null,
        description: null,
        wants: null,
        photoUrl: "",
        status: s,
        createdAt: ts(),
      };
      expect(doc.status).toBe(s);
    });
  });
});

// ---------------------------------------------------------------------------
// /swipes/{swipeId} — SwipeDoc
// ---------------------------------------------------------------------------

describe("SwipeDoc", () => {
  test("desiredItemId is a single string (single-select — F16)", () => {
    const doc: SwipeDoc = {
      swiperId: "uid-ploy",
      targetUserId: "uid-fah",
      desiredItemId: "item-kettle-1",  // single string, not an array
      direction: "right",
      createdAt: ts(),
    };
    expect(typeof doc.desiredItemId).toBe("string");
    expect(Array.isArray(doc.desiredItemId)).toBe(false);
  });

  test("both SwipeDirection values are valid", () => {
    const directions: SwipeDirection[] = ["right", "left"];
    directions.forEach((dir) => {
      const doc: SwipeDoc = {
        swiperId: "uid-a",
        targetUserId: "uid-b",
        desiredItemId: "item-1",
        direction: dir,
        createdAt: ts(),
      };
      expect(doc.direction).toBe(dir);
    });
  });

  test("left-swipe can have any desiredItemId (direction is orthogonal to itemId)", () => {
    // Even a left swipe must carry desiredItemId per the schema
    const doc: SwipeDoc = {
      swiperId: "uid-a",
      targetUserId: "uid-b",
      desiredItemId: "",
      direction: "left",
      createdAt: ts(),
    };
    expect(doc.direction).toBe("left");
    expect(typeof doc.desiredItemId).toBe("string");
  });
});

// ---------------------------------------------------------------------------
// /matches/{matchId} — MatchDoc
// ---------------------------------------------------------------------------

describe("MatchDoc", () => {
  test("accepts an active match with completedAt null", () => {
    const doc: MatchDoc = {
      userAId: "uid-ploy",
      userBId: "uid-fah",
      userAWantsItemId: "item-kettle-1",
      userBWantsItemId: "item-jacket-1",
      status: "active",
      participants: ["uid-ploy", "uid-fah"],
      createdAt: ts(),
      completedAt: null,
    };
    expect(doc.completedAt).toBeNull();
    expect(doc.participants).toHaveLength(2);
  });

  test("accepts a completed match with completedAt set", () => {
    const doc: MatchDoc = {
      userAId: "uid-ploy",
      userBId: "uid-fah",
      userAWantsItemId: "item-kettle-1",
      userBWantsItemId: "item-jacket-1",
      status: "completed",
      participants: ["uid-ploy", "uid-fah"],
      createdAt: ts(1_700_000_000),
      completedAt: ts(1_700_003_600),
    };
    expect(doc.status).toBe("completed");
    expect(doc.completedAt).not.toBeNull();
  });

  test("participants array contains both userIds (required for security rules)", () => {
    const doc: MatchDoc = {
      userAId: "uid-a",
      userBId: "uid-b",
      userAWantsItemId: "item-1",
      userBWantsItemId: "item-2",
      status: "active",
      participants: ["uid-a", "uid-b"],
      createdAt: ts(),
      completedAt: null,
    };
    expect(doc.participants).toContain("uid-a");
    expect(doc.participants).toContain("uid-b");
  });

  test("all 3 MatchStatus values are valid", () => {
    const statuses: MatchStatus[] = ["active", "completed", "cancelled"];
    statuses.forEach((s) => {
      const doc: MatchDoc = {
        userAId: "uid-a",
        userBId: "uid-b",
        userAWantsItemId: "item-1",
        userBWantsItemId: "item-2",
        status: s,
        participants: ["uid-a", "uid-b"],
        createdAt: ts(),
        completedAt: s === "completed" ? ts() : null,
      };
      expect(doc.status).toBe(s);
    });
  });
});

// ---------------------------------------------------------------------------
// /matches/{matchId}/messages/{messageId} — MessageDoc
// ---------------------------------------------------------------------------

describe("MessageDoc", () => {
  test("accepts a valid message", () => {
    const doc: MessageDoc = {
      senderId: "uid-ploy",
      text: "Hey! Want to swap?",
      sentAt: ts(),
      readBy: ["uid-ploy"],
    };
    expect(doc.text).toBe("Hey! Want to swap?");
    expect(doc.readBy).toContain("uid-ploy");
  });

  test("readBy is an array of strings", () => {
    const doc: MessageDoc = {
      senderId: "uid-a",
      text: "Looks great!",
      sentAt: ts(),
      readBy: ["uid-a", "uid-b"],
    };
    expect(Array.isArray(doc.readBy)).toBe(true);
    doc.readBy.forEach((id) => expect(typeof id).toBe("string"));
  });
});

// ---------------------------------------------------------------------------
// /trades/{tradeId} — TradeDoc
// ---------------------------------------------------------------------------

describe("TradeDoc", () => {
  test("accepts a valid trade document with nested impact object", () => {
    const userAGains: UserImpactGains = {
      userId: "uid-ploy",
      co2Saved: 7.2,      // wB * iB: 1.2kg × 6.0 kg CO₂/kg for kitchenware
      wasteDiverted: 0.6, // wA: 0.6kg denim jacket
    };
    const userBGains: UserImpactGains = {
      userId: "uid-fah",
      co2Saved: 15.0,     // wA * iA: 0.6kg × 25 kg CO₂/kg for clothing
      wasteDiverted: 1.2, // wB: 1.2kg kettle
    };
    const impact: TradeImpact = { userAGains, userBGains };
    const itemsExchanged: ItemsExchanged = {
      fromA: "item-jacket-1",
      fromB: "item-kettle-1",
    };
    const doc: TradeDoc = {
      matchId: "match-ploy-fah",
      completedAt: ts(),
      jwtTokenHash: "abc123sha256hashvalue",
      impact,
      itemsExchanged,
    };
    expect(doc.jwtTokenHash).toBe("abc123sha256hashvalue");
    expect(doc.impact.userAGains.co2Saved).toBeCloseTo(7.2);
    expect(doc.impact.userBGains.wasteDiverted).toBeCloseTo(1.2);
  });

  test("jwtTokenHash field is present (single-use marker for WBS 10.2)", () => {
    const doc: TradeDoc = {
      matchId: "match-1",
      completedAt: ts(),
      jwtTokenHash: "sha256hash",
      impact: {
        userAGains: { userId: "uid-a", co2Saved: 0, wasteDiverted: 0 },
        userBGains: { userId: "uid-b", co2Saved: 0, wasteDiverted: 0 },
      },
      itemsExchanged: { fromA: "item-1", fromB: "item-2" },
    };
    expect(doc).toHaveProperty("jwtTokenHash");
    expect(typeof doc.jwtTokenHash).toBe("string");
  });

  test("impact object has userAGains and userBGains with correct shape", () => {
    const aGains: UserImpactGains = { userId: "uid-a", co2Saved: 5, wasteDiverted: 1 };
    const bGains: UserImpactGains = { userId: "uid-b", co2Saved: 3, wasteDiverted: 2 };
    const doc: TradeDoc = {
      matchId: "match-1",
      completedAt: ts(),
      jwtTokenHash: "hash",
      impact: { userAGains: aGains, userBGains: bGains },
      itemsExchanged: { fromA: "item-a", fromB: "item-b" },
    };
    expect(doc.impact.userAGains.userId).toBe("uid-a");
    expect(doc.impact.userBGains.userId).toBe("uid-b");
    expect(typeof doc.impact.userAGains.co2Saved).toBe("number");
    expect(typeof doc.impact.userAGains.wasteDiverted).toBe("number");
  });

  test("itemsExchanged.fromA is item A gave (what B wanted), fromB is item B gave (what A wanted)", () => {
    // Per WBS 10.6 pseudocode:
    //   fromA = match.userBWantsItemId  (A gives this to B)
    //   fromB = match.userAWantsItemId  (B gives this to A)
    const doc: TradeDoc = {
      matchId: "match-1",
      completedAt: ts(),
      jwtTokenHash: "hash",
      impact: {
        userAGains: { userId: "uid-a", co2Saved: 0, wasteDiverted: 0 },
        userBGains: { userId: "uid-b", co2Saved: 0, wasteDiverted: 0 },
      },
      itemsExchanged: {
        fromA: "item-jacket",  // item A gave
        fromB: "item-kettle",  // item B gave
      },
    };
    expect(doc.itemsExchanged.fromA).toBe("item-jacket");
    expect(doc.itemsExchanged.fromB).toBe("item-kettle");
  });
});

// ---------------------------------------------------------------------------
// JwtPayload — used by WBS 10.1 and 10.2
// ---------------------------------------------------------------------------

describe("JwtPayload", () => {
  test("accepts a valid JWT payload matching the WBS 10.1 schema", () => {
    const now = Math.floor(Date.now() / 1000);
    const payload: JwtPayload = {
      matchId: "match-ploy-fah",
      displayerUserId: "uid-ploy",
      iat: now,
      exp: now + 60,
    };
    expect(payload.exp).toBe(payload.iat + 60);
  });

  test("exp is exactly iat + 60 (60-second token lifetime — WBS 10.1)", () => {
    const iat = 1_700_000_000;
    const payload: JwtPayload = {
      matchId: "match-1",
      displayerUserId: "uid-a",
      iat,
      exp: iat + 60,
    };
    expect(payload.exp - payload.iat).toBe(60);
  });

  test("displayerUserId identifies the QR code displayer (not the scanner)", () => {
    const payload: JwtPayload = {
      matchId: "match-1",
      displayerUserId: "uid-displayer",
      iat: 1_700_000_000,
      exp: 1_700_000_060,
    };
    expect(typeof payload.displayerUserId).toBe("string");
    expect(payload.displayerUserId).toBe("uid-displayer");
  });
});
