/**
 * WBS 11.1 — CO₂ Intensity and Typical-Weight Lookup Tables (test suite).
 *
 * Covers the four tests listed in the WBS 11.1 Testing section:
 *   1. Drift detection — the file's category key set equals the canonical
 *      7-element set from WBS 3.6 / CLAUDE.md.
 *   2. Every CO₂ intensity is positive.
 *   3. Every typical weight is positive.
 *   4. Worked example: 0.6 kg of clothing × CO2_INTENSITY.clothing === 15.
 *
 * Note on the "drift detection" test: the canonical category set is
 * duplicated in two languages (TypeScript here, Dart in
 * `lib/constants/impact.dart`). Jest cannot read the Dart file, so we
 * hardcode the canonical 7-element set in this test and assert the
 * TypeScript export matches it. A symmetric test on the Dart side hardcodes
 * the same set and asserts the Dart export matches it. If anyone adds or
 * renames a category in either file without updating the canonical set in
 * BOTH tests, one of the two language-side tests will fail in CI — that is
 * the cross-language drift guard.
 */

import {
  Category,
  CO2_INTENSITY,
  TYPICAL_WEIGHT,
} from "../src/constants/impact";

/**
 * Canonical 7-category set, locked by CLAUDE.md ("Impact calculation" rules)
 * and WBS 3.6 (ItemDoc.category union). Order does not matter for set
 * equality, but the set membership is the locked contract.
 */
const CANONICAL_CATEGORIES: ReadonlyArray<Category> = [
  "clothing",
  "books",
  "kitchenware",
  "household",
  "electronics",
  "furniture",
  "other",
];

describe("WBS 11.1 — CO2_INTENSITY and TYPICAL_WEIGHT lookup tables", () => {
  describe("drift detection (cross-language sync guard)", () => {
    test("CO2_INTENSITY has exactly the canonical 7 keys", () => {
      const keys = Object.keys(CO2_INTENSITY).sort();
      const expected = [...CANONICAL_CATEGORIES].sort();
      expect(keys).toEqual(expected);
      expect(keys).toHaveLength(7);
    });

    test("TYPICAL_WEIGHT has exactly the canonical 7 keys", () => {
      const keys = Object.keys(TYPICAL_WEIGHT).sort();
      const expected = [...CANONICAL_CATEGORIES].sort();
      expect(keys).toEqual(expected);
      expect(keys).toHaveLength(7);
    });

    test("CO2_INTENSITY and TYPICAL_WEIGHT share the same key set", () => {
      const intensityKeys = Object.keys(CO2_INTENSITY).sort();
      const weightKeys = Object.keys(TYPICAL_WEIGHT).sort();
      expect(intensityKeys).toEqual(weightKeys);
    });

    test("no forbidden / renamed categories are present (e.g. 'kitchen')", () => {
      // Common typos / renames that would silently break impact math
      const forbidden = ["kitchen", "appliance", "appliances", "clothes", "book"];
      forbidden.forEach((bad) => {
        expect(Object.keys(CO2_INTENSITY)).not.toContain(bad);
        expect(Object.keys(TYPICAL_WEIGHT)).not.toContain(bad);
      });
    });
  });

  describe("positivity invariants", () => {
    test("every CO2_INTENSITY value is a positive finite number", () => {
      for (const category of CANONICAL_CATEGORIES) {
        const value = CO2_INTENSITY[category];
        expect(typeof value).toBe("number");
        expect(Number.isFinite(value)).toBe(true);
        expect(value).toBeGreaterThan(0);
      }
    });

    test("every TYPICAL_WEIGHT value is a positive finite number", () => {
      for (const category of CANONICAL_CATEGORIES) {
        const value = TYPICAL_WEIGHT[category];
        expect(typeof value).toBe("number");
        expect(Number.isFinite(value)).toBe(true);
        expect(value).toBeGreaterThan(0);
      }
    });
  });

  describe("worked example from WBS 11.1", () => {
    test("clothing 0.6kg × CO2_INTENSITY.clothing === 15", () => {
      const weight = 0.6;
      const co2Saved = weight * CO2_INTENSITY.clothing;
      expect(co2Saved).toBe(15);
    });

    test("locked exact values for the 7 categories", () => {
      // Belt-and-braces: re-assert the exact values from the WBS Constants
      // block so a numeric typo (e.g. clothing: 2.5 instead of 25) fails CI.
      expect(CO2_INTENSITY.clothing).toBe(25);
      expect(CO2_INTENSITY.books).toBe(1.5);
      expect(CO2_INTENSITY.kitchenware).toBe(6);
      expect(CO2_INTENSITY.household).toBe(4);
      expect(CO2_INTENSITY.electronics).toBe(80);
      expect(CO2_INTENSITY.furniture).toBe(4);
      expect(CO2_INTENSITY.other).toBe(5);

      expect(TYPICAL_WEIGHT.clothing).toBe(0.5);
      expect(TYPICAL_WEIGHT.books).toBe(0.4);
      expect(TYPICAL_WEIGHT.kitchenware).toBe(1.0);
      expect(TYPICAL_WEIGHT.household).toBe(0.5);
      expect(TYPICAL_WEIGHT.electronics).toBe(2.0);
      expect(TYPICAL_WEIGHT.furniture).toBe(8.0);
      expect(TYPICAL_WEIGHT.other).toBe(0.5);
    });
  });
});
