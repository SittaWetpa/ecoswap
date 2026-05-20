/// Widget tests for WBS 7.4 — Proximity Filter Bottom Sheet
///
/// Covers the four tests listed in the WBS entry:
///   1. Bottom sheet shows exactly 4 options
///   2. Tapping an option persists the choice and invokes [onChanged]
///   3. [loadProximityBucket] returns the persisted value (app-restart scenario)
///   4. [onChanged] is called with the new bucket so the caller can reload the feed
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/widgets/proximity_filter_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [widget] in a minimal [MaterialApp] so [Navigator] / [MediaQuery]
/// are available.
Widget _wrap(Widget widget) {
  return MaterialApp(home: Scaffold(body: widget));
}

/// Pumps the [ProximityFilterSheet] inside a [showModalBottomSheet] call,
/// so all the sheet animations and Navigator machinery are exercised.
Future<void> _showSheet(
  WidgetTester tester, {
  required ProximityBucket current,
  required ValueChanged<ProximityBucket> onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => ProximityFilterSheet.show(
              ctx,
              current: current,
              onChanged: onChanged,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Reset SharedPreferences between tests so state doesn't bleed over.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------------
  // 1. Bottom sheet shows exactly 4 options
  // -------------------------------------------------------------------------
  group('ProximityFilterSheet — 4 options', () {
    testWidgets('renders exactly 4 option rows', (tester) async {
      await _showSheet(
        tester,
        current: ProximityBucket.sameProvince,
        onChanged: (_) {},
      );

      // Each option row shows its label text.
      expect(find.text('Same district'), findsOneWidget);
      expect(find.text('Same province'), findsOneWidget);
      expect(find.text('Nearby provinces'), findsOneWidget);
      expect(find.text('All Thailand'), findsOneWidget);

      // Confirm the list contains exactly the 4 known labels — no extras.
      for (final opt in kProximityOptions) {
        expect(find.text(opt.label), findsOneWidget);
      }
      expect(kProximityOptions.length, 4);
    });

    testWidgets('renders the sheet title and subtitle text', (tester) async {
      await _showSheet(
        tester,
        current: ProximityBucket.sameProvince,
        onChanged: (_) {},
      );

      expect(find.text('Show me swappers in…'), findsOneWidget);
      expect(
        find.text('Wider ranges show more people but less local matches.'),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. Tapping an option invokes onChanged with the correct bucket
  // -------------------------------------------------------------------------
  group('ProximityFilterSheet — tapping an option', () {
    testWidgets(
        'calls onChanged with the tapped bucket and persists to SharedPreferences',
        (tester) async {
      ProximityBucket? received;

      await _showSheet(
        tester,
        current: ProximityBucket.sameProvince,
        onChanged: (b) => received = b,
      );

      await tester.tap(find.text('All Thailand'));
      await tester.pumpAndSettle();

      // onChanged fires with the correct value.
      expect(received, ProximityBucket.allThailand);

      // SharedPreferences has the persisted key.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProximityFilterSheet.prefKey), 'thailand');
    });

    testWidgets('calls onChanged with sameDistrict when that row is tapped',
        (tester) async {
      ProximityBucket? received;

      await _showSheet(
        tester,
        current: ProximityBucket.allThailand,
        onChanged: (b) => received = b,
      );

      await tester.tap(find.text('Same district'));
      await tester.pumpAndSettle();

      expect(received, ProximityBucket.sameDistrict);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ProximityFilterSheet.prefKey), 'district');
    });
  });

  // -------------------------------------------------------------------------
  // 3. App-restart: persisted value survives (loadProximityBucket round-trip)
  // -------------------------------------------------------------------------
  group('loadProximityBucket / saveProximityBucket — persistence', () {
    testWidgets('returns sameProvince by default (no stored key)', (tester) async {
      final bucket = await loadProximityBucket();
      expect(bucket, ProximityBucket.sameProvince);
    });

    testWidgets('round-trips every bucket value correctly', (tester) async {
      for (final bucket in ProximityBucket.values) {
        SharedPreferences.setMockInitialValues({});
        await saveProximityBucket(bucket);
        final loaded = await loadProximityBucket();
        expect(
          loaded,
          bucket,
          reason: 'bucket ${bucket.name} should survive a save/load round-trip',
        );
      }
    });

    testWidgets('saved selection is still present after re-reading prefs',
        (tester) async {
      // Simulate selecting "Nearby provinces"
      await saveProximityBucket(ProximityBucket.nearbyProvinces);

      // A "cold-start" read via loadProximityBucket should return it.
      final reloaded = await loadProximityBucket();
      expect(reloaded, ProximityBucket.nearbyProvinces);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Changing the filter triggers onChanged so the feed service can reload
  // -------------------------------------------------------------------------
  group('ProximityFilterSheet — feed reload wiring', () {
    testWidgets('onChanged fires once per tap with the new bucket',
        (tester) async {
      final received = <ProximityBucket>[];

      await _showSheet(
        tester,
        current: ProximityBucket.sameDistrict,
        onChanged: received.add,
      );

      await tester.tap(find.text('Same province'));
      await tester.pumpAndSettle();

      expect(received, hasLength(1));
      expect(received.first, ProximityBucket.sameProvince);
    });

    testWidgets('ProximityPill shows the current bucket label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProximityPill(
            bucket: ProximityBucket.nearbyProvinces,
            onTap: () {},
          ),
        ),
      );

      // The pill must show the human-readable label, not the enum name.
      expect(find.text('Nearby provinces'), findsOneWidget);
    });

    testWidgets('ProximityPill fires onTap callback when tapped',
        (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(
          ProximityPill(
            bucket: ProximityBucket.allThailand,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(ProximityPill));
      expect(tapped, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Selected row is visually marked
  // -------------------------------------------------------------------------
  group('ProximityFilterSheet — selection highlight', () {
    testWidgets('the currently selected option shows a checkmark icon',
        (tester) async {
      await _showSheet(
        tester,
        current: ProximityBucket.sameDistrict,
        onChanged: (_) {},
      );

      // There should be exactly one check icon (the selected row).
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 6. proximityLabel helper
  // -------------------------------------------------------------------------
  group('proximityLabel', () {
    test('returns the correct label for every bucket', () {
      expect(proximityLabel(ProximityBucket.sameDistrict), 'Same district');
      expect(proximityLabel(ProximityBucket.sameProvince), 'Same province');
      expect(proximityLabel(ProximityBucket.nearbyProvinces), 'Nearby provinces');
      expect(proximityLabel(ProximityBucket.allThailand), 'All Thailand');
    });
  });
}
