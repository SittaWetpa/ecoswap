/**
 * Firestore document type definitions for EcoSwap.
 * WBS 3.6 — Firestore Data Model Implementation
 *
 * These interfaces are the canonical TypeScript representation of every
 * collection's document shape.  They are consumed by every Cloud Function
 * that reads or writes Firestore.
 *
 * Schema source: docs/EcoSwap_WBS_Dictionary.md § 3.6
 * Locked decisions enforced here:
 *   - homeDistrict has exactly 6 string fields — no lat/lng/centroid
 *   - Trust score field is NOT present on UserDoc
 *   - tradesCount / totalCo2Saved / totalWasteDiverted exist on UserDoc (default 0)
 *   - desiredItemId on SwipeDoc is a single string (F16 single-select)
 *   - jwtTokenHash and nested impact object are present on TradeDoc
 */

import type { Timestamp } from "firebase-admin/firestore";

// ---------------------------------------------------------------------------
// /users/{userId}
// ---------------------------------------------------------------------------

/**
 * Six-string district object sourced from kongvut/thai-province-data.
 * No GPS, no lat/lng, no centroid — see CLAUDE.md location model rules.
 */
export interface HomeDistrict {
  provinceId: string;      // e.g. "10" (Bangkok)
  provinceNameTh: string;  // e.g. "กรุงเทพมหานคร"
  provinceNameEn: string;  // e.g. "Bangkok"
  districtId: string;      // e.g. "1023"
  districtNameTh: string;  // e.g. "บางมด"
  districtNameEn: string;  // e.g. "Bang Mod"
}

/**
 * /users/{userId}
 *
 * Note: there is NO trustScore field — it was cut as a Should-Have.
 * The three counter fields (tradesCount, totalCo2Saved, totalWasteDiverted)
 * are written ONLY by the Cloud Function in WBS 10.6 — clients may not write
 * these fields directly (enforced by Firestore security rules in WBS 3.2).
 */
export interface UserDoc {
  email: string;
  displayName: string;
  photoUrl: string;
  homeDistrict: HomeDistrict;
  bio: string;             // max 140 chars
  createdAt: Timestamp;
  tradesCount: number;         // denormalized; default 0
  totalCo2Saved: number;       // kg, denormalized; default 0
  totalWasteDiverted: number;  // kg, denormalized; default 0
}

// ---------------------------------------------------------------------------
// /items/{itemId}
// ---------------------------------------------------------------------------

export type ItemCategory =
  | "clothing"
  | "books"
  | "kitchenware"
  | "household"
  | "electronics"
  | "furniture"
  | "other";

export type ItemCondition = "new" | "like-new" | "good" | "used";

export type ItemStatus = "active" | "traded" | "deleted";

/** /items/{itemId} */
export interface ItemDoc {
  ownerId: string;
  name: string;
  category: ItemCategory;
  condition: ItemCondition;
  weight: number | null;       // kg, optional; null means use category typical weight
  description: string | null;
  wants: string | null;
  photoUrl: string;
  status: ItemStatus;
  createdAt: Timestamp;
}

// ---------------------------------------------------------------------------
// /swipes/{swipeId}
// ---------------------------------------------------------------------------

export type SwipeDirection = "right" | "left";

/**
 * /swipes/{swipeId}
 *
 * desiredItemId is a single string (F16 — single-select item picker).
 * Multi-select is explicitly out of scope; do not change to string[].
 */
export interface SwipeDoc {
  swiperId: string;
  targetUserId: string;
  desiredItemId: string;       // single-select, per F16
  direction: SwipeDirection;
  createdAt: Timestamp;
}

// ---------------------------------------------------------------------------
// /matches/{matchId}
// ---------------------------------------------------------------------------

export type MatchStatus = "active" | "completed" | "cancelled";

/** /matches/{matchId} */
export interface MatchDoc {
  userAId: string;
  userBId: string;
  userAWantsItemId: string;    // what A picked of B's items
  userBWantsItemId: string;    // what B picked of A's items
  status: MatchStatus;
  participants: string[];      // [userAId, userBId] — for security rules
  createdAt: Timestamp;
  completedAt: Timestamp | null;
}

// ---------------------------------------------------------------------------
// /matches/{matchId}/messages/{messageId}
// ---------------------------------------------------------------------------

/** /matches/{matchId}/messages/{messageId} */
export interface MessageDoc {
  senderId: string;
  text: string;
  sentAt: Timestamp;           // serverTimestamp()
  readBy: string[];
}

// ---------------------------------------------------------------------------
// /trades/{tradeId}
// ---------------------------------------------------------------------------

/**
 * Per-user impact contribution within a single trade.
 * CO₂ saved = weight of item received × category intensity.
 * Waste diverted = weight of item given.
 * Computed server-side by writeTradeAndImpact (WBS 10.6).
 */
export interface UserImpactGains {
  userId: string;
  co2Saved: number;        // kg CO₂ equivalent
  wasteDiverted: number;   // kg waste
}

export interface TradeImpact {
  userAGains: UserImpactGains;
  userBGains: UserImpactGains;
}

export interface ItemsExchanged {
  fromA: string;  // itemId that user A gave (what B wanted)
  fromB: string;  // itemId that user B gave (what A wanted)
}

/**
 * /trades/{tradeId}
 *
 * Written ONLY by the Cloud Function in WBS 10.6 — clients may not write
 * to /trades/ directly (enforced by Firestore security rules in WBS 3.2).
 *
 * jwtTokenHash: SHA-256 of the JWT, used as a single-use marker to prevent
 * the same QR code from completing more than one trade.
 */
export interface TradeDoc {
  matchId: string;
  completedAt: Timestamp;
  jwtTokenHash: string;        // SHA-256 of the token — single-use marker
  impact: TradeImpact;
  itemsExchanged: ItemsExchanged;
}

// ---------------------------------------------------------------------------
// JWT payload (WBS 10.1)
// Used by issueQRToken and validateQRToken.
// ---------------------------------------------------------------------------

/**
 * The payload embedded in the signed HS256 JWT.
 * Defined here alongside the Firestore types because validateQRToken (10.2)
 * reads both the JWT payload and Firestore documents in the same transaction.
 */
export interface JwtPayload {
  matchId: string;
  displayerUserId: string;  // who is showing the QR
  iat: number;              // issued-at, seconds since epoch
  exp: number;              // expiry = iat + 60
}
