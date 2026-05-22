/**
 * WBS 11.1 — CO₂ Intensity and Typical-Weight Lookup Tables (TypeScript copy).
 *
 * Source: §8.4 of EcoSwap Planning Package. Must be kept in sync with the
 * other copy.
 *
 * The "other copy" is `lib/constants/impact.dart`. Both files must declare
 * the same 7 categories and the same numeric values; any change here MUST
 * be mirrored there (and vice versa). Drift is caught by symmetric unit
 * tests on each side of the language boundary — see
 * `functions/test/impact.test.ts` (this side) and the corresponding Dart
 * test on the Flutter side.
 *
 * Consumed by:
 *   - WBS 10.6 (`functions/src/writeTradeAndImpact.ts`) — server-side impact
 *     computation inside the trade-write transaction.
 *   - WBS 6.2 (`lib/.../upload_item.dart`) — client-side typical-weight hints
 *     in the Upload Item form (via the Dart copy).
 *
 * Formula (per WBS 10.6 and 11.1):
 *   co2Saved      = weight_of_item_received × CO2_INTENSITY[category_received]
 *   wasteDiverted = weight_of_item_given
 *
 * Per-user attribution: each user gets CO₂ for what they RECEIVED and waste
 * for what they GAVE. The Cloud Function in WBS 10.6 is the only writer of
 * the `/users/` counter fields.
 */

/**
 * The 7 categories locked by WBS 3.6 and CLAUDE.md. Do not add or rename.
 * `kitchenware` is `kitchenware`, not `kitchen`.
 *
 * This is structurally identical to `ItemCategory` in `functions/src/types.ts`
 * — we redeclare it here so this constants module has no runtime dependency
 * on the types module, and so the lookup table's key set is locally
 * self-describing. The drift test in `impact.test.ts` enforces equality
 * against the canonical 7-element set.
 */
export type Category =
  | "clothing"
  | "books"
  | "kitchenware"
  | "household"
  | "electronics"
  | "furniture"
  | "other";

/**
 * CO₂ intensity per category, in kg CO₂ equivalent per kg of item.
 * Values are locked by the WBS 11.1 Constants block.
 */
export const CO2_INTENSITY: Record<Category, number> = {
  clothing: 25,
  books: 1.5,
  kitchenware: 6,
  household: 4,
  electronics: 80,
  furniture: 4,
  other: 5,
};

/**
 * Typical weight per category, in kg. Used as a fallback when an item's
 * `weight` field is null (see WBS 3.6 ItemDoc.weight and the WBS 10.6
 * `tx.get` pseudocode: `weight ?? TYPICAL_WEIGHT[category]`).
 * Values are locked by the WBS 11.1 Constants block.
 */
export const TYPICAL_WEIGHT: Record<Category, number> = {
  clothing: 0.5,
  books: 0.4,
  kitchenware: 1.0,
  household: 0.5,
  electronics: 2.0,
  furniture: 8.0,
  other: 0.5,
};
