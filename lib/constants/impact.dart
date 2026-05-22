/// WBS 11.1 — CO₂ Intensity and Typical-Weight Lookup Tables (Dart copy).
///
/// Source: §8.4 of EcoSwap Planning Package. Must be kept in sync with the
/// other copy.
///
/// The "other copy" is `functions/src/constants/impact.ts`. Both files must
/// declare the same 7 categories and the same numeric values; any change
/// here MUST be mirrored there (and vice versa). Drift is caught by
/// symmetric unit tests on each side of the language boundary — see
/// `test/constants/impact_test.dart` (this side) and
/// `functions/test/impact.test.ts` on the Cloud Functions side.
///
/// Consumed by:
///   - WBS 6.2 (`lib/.../upload_item.dart`) — client-side typical-weight
///     hints in the Upload Item form (e.g. "0.5 kg typical for clothing").
///   - WBS 11.3 and 11.4 — Impact Dashboard / Profile impact strip, which
///     read pre-computed denormalized counters; they do not recompute, but
///     the unit labels reference these intensities.
///
/// Formula (per WBS 10.6 and 11.1):
///   co2Saved      = weight_of_item_received × co2Intensity[category_received]
///   wasteDiverted = weight_of_item_given
///
/// Per-user attribution: each user gets CO₂ for what they RECEIVED and
/// waste for what they GAVE. The Cloud Function in WBS 10.6 is the only
/// writer of the `/users/` counter fields — this Dart file is for UI hints
/// only, never for client-side impact writes.
library;

/// The 7 categories locked by WBS 3.6 and CLAUDE.md. Do not add or rename.
/// `kitchenware` is `kitchenware`, not `kitchen`.
///
/// The drift test in `test/constants/impact_test.dart` enforces equality
/// against the canonical 7-element set and against the TypeScript copy.
const List<String> impactCategories = <String>[
  'clothing',
  'books',
  'kitchenware',
  'household',
  'electronics',
  'furniture',
  'other',
];

/// CO₂ intensity per category, in kg CO₂ equivalent per kg of item.
/// Values are locked by the WBS 11.1 Constants block.
const Map<String, double> co2Intensity = <String, double>{
  'clothing': 25,
  'books': 1.5,
  'kitchenware': 6,
  'household': 4,
  'electronics': 80,
  'furniture': 4,
  'other': 5,
};

/// Typical weight per category, in kg. Used as a fallback when an item's
/// `weight` field is null (see WBS 3.6 ItemDoc.weight and the WBS 10.6
/// `tx.get` pseudocode: `weight ?? TYPICAL_WEIGHT[category]`).
/// Values are locked by the WBS 11.1 Constants block.
const Map<String, double> typicalWeight = <String, double>{
  'clothing': 0.5,
  'books': 0.4,
  'kitchenware': 1.0,
  'household': 0.5,
  'electronics': 2.0,
  'furniture': 8.0,
  'other': 0.5,
};
