/// WBS 10.6 — Impact formula unit tests (Flutter/Dart side).
///
/// The impact formula is computed server-side inside `writeTradeAndImpact`
/// (functions/src/writeTradeAndImpact.ts). These tests verify that the Dart
/// copies of the lookup constants in `lib/constants/impact.dart` reproduce
/// the same numeric results as the canonical pseudocode in the WBS 10.6
/// entry, using the same formula:
///
///   aCo2   = wB * co2Intensity[bCategory]   (A receives B's item)
///   aWaste = wA                              (A gave away A's item)
///   bCo2   = wA * co2Intensity[aCategory]   (B receives A's item)
///   bWaste = wB                              (B gave away B's item)
///
/// where wX is itemX.weight ?? typicalWeight[itemX.category].
///
/// These tests are the Dart-side mirror of the Jest tests in
/// `functions/test/writeTradeAndImpact.test.ts` and directly fulfil the
/// three WBS 10.6 unit-test requirements:
///   1. Worked example (Ploy's jacket ⇄ Fah's kettle) → correct values.
///   2. Null weight falls back to typical.
///   3. All 7 categories produce non-NaN, non-negative impact values.
library;

import 'package:ecoswap/constants/impact.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers — replicate the formula from WBS 10.6 pseudocode in Dart
// ---------------------------------------------------------------------------

/// Represents one side of the impact computation.
class _ImpactPair {
  final double co2Saved;
  final double wasteDiverted;

  const _ImpactPair({required this.co2Saved, required this.wasteDiverted});
}

class _ImpactResult {
  final _ImpactPair userA;
  final _ImpactPair userB;

  const _ImpactResult({required this.userA, required this.userB});
}

/// Replicates the pseudocode from WBS 10.6 in pure Dart.
///
/// [aCategory]  — category of A's item (the one A gives to B).
/// [aWeight]    — weight of A's item in kg; null → use typicalWeight.
/// [bCategory]  — category of B's item (the one B gives to A).
/// [bWeight]    — weight of B's item in kg; null → use typicalWeight.
_ImpactResult _computeImpact({
  required String aCategory,
  double? aWeight,
  required String bCategory,
  double? bWeight,
}) {
  final wA = aWeight ?? typicalWeight[aCategory]!;
  final wB = bWeight ?? typicalWeight[bCategory]!;
  final iA = co2Intensity[aCategory]!;
  final iB = co2Intensity[bCategory]!;

  // A receives bGives (B's item); A's CO₂ = wB * iB; A's waste = wA.
  final aCo2 = wB * iB;
  final aWaste = wA;

  // B receives aGives (A's item); B's CO₂ = wA * iA; B's waste = wB.
  final bCo2 = wA * iA;
  final bWaste = wB;

  return _ImpactResult(
    userA: _ImpactPair(co2Saved: aCo2, wasteDiverted: aWaste),
    userB: _ImpactPair(co2Saved: bCo2, wasteDiverted: bWaste),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WBS 10.6 — impact formula unit tests', () {
    // ── Test 1: worked example from WBS 11.1 ──────────────────────────────
    //
    // Ploy gives her denim jacket (clothing, 0.6 kg).
    // Fah gives her electric kettle (kitchenware, 1.2 kg).
    //
    // Expected (from WBS 10.6 entry and WBS 11.1):
    //   aCo2   = 1.2 × co2Intensity['kitchenware'] = 1.2 × 6  = 7.2
    //   aWaste = 0.6 (the jacket Ploy gave away)
    //   bCo2   = 0.6 × co2Intensity['clothing']    = 0.6 × 25 = 15.0
    //   bWaste = 1.2 (the kettle Fah gave away)

    test('worked example (Ploy jacket 0.6 kg ⇄ Fah kettle 1.2 kg) → '
        'aCo2=7.2, aWaste=0.6, bCo2=15.0, bWaste=1.2', () {
      final result = _computeImpact(
        aCategory: 'clothing',
        aWeight: 0.6,
        bCategory: 'kitchenware',
        bWeight: 1.2,
      );

      // Use closeTo for floating-point results — 1.2 × 6 is 7.199999…
      // in IEEE-754 arithmetic, identical to the TypeScript side.
      expect(result.userA.co2Saved, closeTo(7.2, 1e-9));
      expect(result.userA.wasteDiverted, closeTo(0.6, 1e-9));
      expect(result.userB.co2Saved, closeTo(15.0, 1e-9));
      expect(result.userB.wasteDiverted, closeTo(1.2, 1e-9));
    });

    // ── Test 2: null weight falls back to category typical ─────────────────
    //
    // When an item's weight field is null the formula uses
    // typicalWeight[category] as the weight. Verify for both sides.

    test('null weight for A falls back to typicalWeight[aCategory]', () {
      // aWeight = null → use typicalWeight['clothing'] = 0.5
      // bWeight = 1.2 kg kitchenware (explicit)
      final result = _computeImpact(
        aCategory: 'clothing',
        aWeight: null, // triggers fallback
        bCategory: 'kitchenware',
        bWeight: 1.2,
      );

      final expectedWA = typicalWeight['clothing']!; // 0.5
      final expectedACo2 = 1.2 * co2Intensity['kitchenware']!; // 1.2 × 6 = 7.2
      final expectedBCo2 =
          expectedWA * co2Intensity['clothing']!; // 0.5 × 25 = 12.5

      expect(result.userA.co2Saved, equals(expectedACo2));
      expect(result.userA.wasteDiverted, equals(expectedWA));
      expect(result.userB.co2Saved, equals(expectedBCo2));
      expect(result.userB.wasteDiverted, equals(1.2));
    });

    test('null weight for B falls back to typicalWeight[bCategory]', () {
      // aWeight = 0.6 kg clothing (explicit)
      // bWeight = null → use typicalWeight['kitchenware'] = 1.0
      final result = _computeImpact(
        aCategory: 'clothing',
        aWeight: 0.6,
        bCategory: 'kitchenware',
        bWeight: null, // triggers fallback
      );

      final expectedWB = typicalWeight['kitchenware']!; // 1.0
      final expectedACo2 =
          expectedWB * co2Intensity['kitchenware']!; // 1.0 × 6 = 6.0
      final expectedBCo2 = 0.6 * co2Intensity['clothing']!; // 0.6 × 25 = 15.0

      expect(result.userA.co2Saved, equals(expectedACo2));
      expect(result.userA.wasteDiverted, equals(0.6));
      expect(result.userB.co2Saved, equals(expectedBCo2));
      expect(result.userB.wasteDiverted, equals(expectedWB));
    });

    test(
      'null weights on both sides both fall back to their respective typicals',
      () {
        // Both weights null — use typicals for both.
        final result = _computeImpact(
          aCategory: 'electronics',
          aWeight: null,
          bCategory: 'furniture',
          bWeight: null,
        );

        final wA = typicalWeight['electronics']!; // 2.0
        final wB = typicalWeight['furniture']!; // 8.0
        final iA = co2Intensity['electronics']!; // 80
        final iB = co2Intensity['furniture']!; // 4

        expect(result.userA.co2Saved, equals(wB * iB)); // 8.0 × 4 = 32.0
        expect(result.userA.wasteDiverted, equals(wA)); // 2.0
        expect(result.userB.co2Saved, equals(wA * iA)); // 2.0 × 80 = 160.0
        expect(result.userB.wasteDiverted, equals(wB)); // 8.0
      },
    );

    // ── Test 3: all 7 categories produce non-NaN, non-negative values ──────
    //
    // For every pair of categories (including same × same), the formula must
    // produce finite, non-negative numbers. This guards against any lookup
    // table entry that is 0, negative, or missing.

    test('all 7 categories produce non-NaN, non-negative impact values '
        '(using typical weights)', () {
      for (final catA in impactCategories) {
        for (final catB in impactCategories) {
          final result = _computeImpact(
            aCategory: catA,
            aWeight: null, // use typical
            bCategory: catB,
            bWeight: null, // use typical
          );

          expect(
            result.userA.co2Saved.isNaN,
            isFalse,
            reason: 'aCo2 is NaN for ($catA, $catB)',
          );
          expect(
            result.userA.co2Saved.isInfinite,
            isFalse,
            reason: 'aCo2 is infinite for ($catA, $catB)',
          );
          expect(
            result.userA.co2Saved,
            greaterThanOrEqualTo(0),
            reason: 'aCo2 is negative for ($catA, $catB)',
          );

          expect(
            result.userA.wasteDiverted.isNaN,
            isFalse,
            reason: 'aWaste is NaN for ($catA, $catB)',
          );
          expect(
            result.userA.wasteDiverted,
            greaterThanOrEqualTo(0),
            reason: 'aWaste is negative for ($catA, $catB)',
          );

          expect(
            result.userB.co2Saved.isNaN,
            isFalse,
            reason: 'bCo2 is NaN for ($catA, $catB)',
          );
          expect(
            result.userB.co2Saved.isInfinite,
            isFalse,
            reason: 'bCo2 is infinite for ($catA, $catB)',
          );
          expect(
            result.userB.co2Saved,
            greaterThanOrEqualTo(0),
            reason: 'bCo2 is negative for ($catA, $catB)',
          );

          expect(
            result.userB.wasteDiverted.isNaN,
            isFalse,
            reason: 'bWaste is NaN for ($catA, $catB)',
          );
          expect(
            result.userB.wasteDiverted,
            greaterThanOrEqualTo(0),
            reason: 'bWaste is negative for ($catA, $catB)',
          );
        }
      }
    });

    // ── Additional: formula symmetry check ────────────────────────────────
    //
    // Swapping A and B swaps who got CO₂ and who got waste. This confirms
    // the formula is correctly attributed (not just summed).

    test('swapping A and B roles swaps the CO₂ and waste attributions', () {
      const catA = 'books';
      const catB = 'household';
      const wA = 0.4; // explicit weights to avoid any typical ambiguity
      const wB = 0.5;

      final resultAB = _computeImpact(
        aCategory: catA,
        aWeight: wA,
        bCategory: catB,
        bWeight: wB,
      );
      final resultBA = _computeImpact(
        aCategory: catB,
        aWeight: wB,
        bCategory: catA,
        bWeight: wA,
      );

      // When A and B swap roles, A in resultAB ≡ B in resultBA.
      expect(resultAB.userA.co2Saved, equals(resultBA.userB.co2Saved));
      expect(
        resultAB.userA.wasteDiverted,
        equals(resultBA.userB.wasteDiverted),
      );
      expect(resultAB.userB.co2Saved, equals(resultBA.userA.co2Saved));
      expect(
        resultAB.userB.wasteDiverted,
        equals(resultBA.userA.wasteDiverted),
      );
    });
  });
}
