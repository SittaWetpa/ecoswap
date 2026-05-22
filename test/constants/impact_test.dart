/// WBS 11.1 — CO₂ Intensity and Typical-Weight Lookup Tables (test suite).
///
/// Covers the four tests listed in the WBS 11.1 Testing section:
///   1. Drift detection — the Dart file's category key set equals the
///      canonical 7-element set from WBS 3.6 / CLAUDE.md, the TypeScript
///      file's key set equals the same canonical set, and for every
///      category the numeric values in the two files are equal for both
///      CO2_INTENSITY and TYPICAL_WEIGHT.
///   2. Every CO₂ intensity is positive.
///   3. Every typical weight is positive.
///   4. Worked example: 0.6 kg of clothing × co2Intensity['clothing'] === 15.
///
/// The drift test reads `functions/src/constants/impact.ts` as text via
/// `dart:io File` and parses out the literal map entries with a simple
/// regex. This means a numeric typo on EITHER side of the language
/// boundary (e.g. someone bumps clothing CO₂ from 25 to 30 in only one
/// file) will fail this test in CI. The symmetric Jest test on the TS
/// side hardcodes the canonical set so renaming a category there without
/// updating the Dart side also fails CI — together the two tests form the
/// cross-language drift guard required by WBS 11.1.
library;

import 'dart:io';

import 'package:ecoswap/constants/impact.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canonical 7-category set, locked by CLAUDE.md ("Impact calculation"
/// rules) and WBS 3.6 (ItemDoc.category union). Order does not matter for
/// set equality, but the membership is the locked contract.
const Set<String> canonicalCategories = <String>{
  'clothing',
  'books',
  'kitchenware',
  'household',
  'electronics',
  'furniture',
  'other',
};

/// Locate the TypeScript constants file relative to the test working
/// directory. `flutter test` runs from the repo root, so the relative
/// path is stable.
File _tsConstantsFile() {
  final file = File('functions/src/constants/impact.ts');
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'Expected to find functions/src/constants/impact.ts relative to the '
        'flutter test working directory (the repo root). If this test was '
        'moved or invoked from a different cwd, adjust the path.',
  );
  return file;
}

/// Parse the body of a named TypeScript const map of shape:
///
/// ```ts
/// export const NAME: Record<Category, number> = {
///   clothing: 25,
///   ...
/// };
/// ```
///
/// into a `Map<String, double>`. Whitespace-tolerant, comment-tolerant.
/// Throws via `fail()` if the named block cannot be found.
Map<String, double> _parseTsMap(String source, String constName) {
  // Match `export const NAME ... = { ... };` (smallest body, non-greedy).
  final blockRegex = RegExp(
    r'export\s+const\s+' +
        RegExp.escape(constName) +
        r'\s*:\s*[^=]*=\s*\{([^}]*)\}\s*;',
    multiLine: true,
  );
  final blockMatch = blockRegex.firstMatch(source);
  if (blockMatch == null) {
    fail('Could not find `export const $constName` block in impact.ts');
  }
  final body = blockMatch.group(1)!;

  // Match `key: number,` entries. Keys are bare identifiers (no quotes in
  // the current TS source); values are integers or decimals.
  final entryRegex = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([0-9]+(?:\.[0-9]+)?)');
  final result = <String, double>{};
  for (final m in entryRegex.allMatches(body)) {
    final key = m.group(1)!;
    final value = double.parse(m.group(2)!);
    result[key] = value;
  }
  expect(
    result,
    isNotEmpty,
    reason: 'Parsed $constName block but found no key:number entries — '
        'regex likely mismatched the file format.',
  );
  return result;
}

void main() {
  group('WBS 11.1 — co2Intensity and typicalWeight lookup tables', () {
    group('drift detection (Dart side)', () {
      test('co2Intensity has exactly the canonical 7 keys', () {
        expect(co2Intensity.keys.toSet(), equals(canonicalCategories));
        expect(co2Intensity.length, equals(7));
      });

      test('typicalWeight has exactly the canonical 7 keys', () {
        expect(typicalWeight.keys.toSet(), equals(canonicalCategories));
        expect(typicalWeight.length, equals(7));
      });

      test('co2Intensity and typicalWeight share the same key set', () {
        expect(co2Intensity.keys.toSet(), equals(typicalWeight.keys.toSet()));
      });

      test('impactCategories list matches the canonical set', () {
        expect(impactCategories.toSet(), equals(canonicalCategories));
        expect(impactCategories.length, equals(7));
      });

      test('no forbidden / renamed categories are present (e.g. "kitchen")',
          () {
        // Common typos / renames that would silently break impact math.
        const forbidden = <String>[
          'kitchen',
          'appliance',
          'appliances',
          'clothes',
          'book',
        ];
        for (final bad in forbidden) {
          expect(co2Intensity.containsKey(bad), isFalse,
              reason: 'co2Intensity must not contain forbidden key "$bad"');
          expect(typicalWeight.containsKey(bad), isFalse,
              reason: 'typicalWeight must not contain forbidden key "$bad"');
        }
      });
    });

    group('drift detection (cross-language sync vs TypeScript copy)', () {
      late final String tsSource;
      late final Map<String, double> tsCo2Intensity;
      late final Map<String, double> tsTypicalWeight;

      setUpAll(() {
        tsSource = _tsConstantsFile().readAsStringSync();
        tsCo2Intensity = _parseTsMap(tsSource, 'CO2_INTENSITY');
        tsTypicalWeight = _parseTsMap(tsSource, 'TYPICAL_WEIGHT');
      });

      test('TS CO2_INTENSITY has exactly the canonical 7 keys', () {
        expect(tsCo2Intensity.keys.toSet(), equals(canonicalCategories));
        expect(tsCo2Intensity.length, equals(7));
      });

      test('TS TYPICAL_WEIGHT has exactly the canonical 7 keys', () {
        expect(tsTypicalWeight.keys.toSet(), equals(canonicalCategories));
        expect(tsTypicalWeight.length, equals(7));
      });

      test('Dart and TS CO2_INTENSITY values match for every category', () {
        for (final category in canonicalCategories) {
          expect(
            co2Intensity[category],
            equals(tsCo2Intensity[category]),
            reason: 'co2Intensity drift for "$category": '
                'Dart=${co2Intensity[category]} vs TS=${tsCo2Intensity[category]}',
          );
        }
      });

      test('Dart and TS TYPICAL_WEIGHT values match for every category', () {
        for (final category in canonicalCategories) {
          expect(
            typicalWeight[category],
            equals(tsTypicalWeight[category]),
            reason: 'typicalWeight drift for "$category": '
                'Dart=${typicalWeight[category]} vs TS=${tsTypicalWeight[category]}',
          );
        }
      });
    });

    group('positivity invariants', () {
      test('every co2Intensity value is a positive finite number', () {
        for (final category in canonicalCategories) {
          final value = co2Intensity[category];
          expect(value, isNotNull,
              reason: 'co2Intensity missing key "$category"');
          expect(value!.isFinite, isTrue);
          expect(value, greaterThan(0));
        }
      });

      test('every typicalWeight value is a positive finite number', () {
        for (final category in canonicalCategories) {
          final value = typicalWeight[category];
          expect(value, isNotNull,
              reason: 'typicalWeight missing key "$category"');
          expect(value!.isFinite, isTrue);
          expect(value, greaterThan(0));
        }
      });
    });

    group('worked example from WBS 11.1', () {
      test('clothing 0.6kg × co2Intensity[clothing] === 15', () {
        const weight = 0.6;
        final co2Saved = weight * co2Intensity['clothing']!;
        expect(co2Saved, equals(15));
      });

      test('locked exact values for the 7 categories', () {
        // Belt-and-braces: re-assert the exact values from the WBS
        // Constants block so a numeric typo (e.g. clothing: 2.5 instead
        // of 25) fails CI even if the TS file happens to have the same
        // typo.
        expect(co2Intensity['clothing'], equals(25));
        expect(co2Intensity['books'], equals(1.5));
        expect(co2Intensity['kitchenware'], equals(6));
        expect(co2Intensity['household'], equals(4));
        expect(co2Intensity['electronics'], equals(80));
        expect(co2Intensity['furniture'], equals(4));
        expect(co2Intensity['other'], equals(5));

        expect(typicalWeight['clothing'], equals(0.5));
        expect(typicalWeight['books'], equals(0.4));
        expect(typicalWeight['kitchenware'], equals(1.0));
        expect(typicalWeight['household'], equals(0.5));
        expect(typicalWeight['electronics'], equals(2.0));
        expect(typicalWeight['furniture'], equals(8.0));
        expect(typicalWeight['other'], equals(0.5));
      });
    });
  });
}
