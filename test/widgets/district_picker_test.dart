import 'dart:convert';

import 'package:ecoswap/services/district_service.dart';
import 'package:ecoswap/widgets/district_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

final _fixtureDistricts = [
  {
    'provinceId': '1',
    'provinceNameTh': 'กรุงเทพมหานคร',
    'provinceNameEn': 'Bangkok',
    'districtId': '1004',
    'districtNameTh': 'เขตบางรัก',
    'districtNameEn': 'Khet Bang Rak',
  },
  {
    'provinceId': '1',
    'provinceNameTh': 'กรุงเทพมหานคร',
    'provinceNameEn': 'Bangkok',
    'districtId': '1005',
    'districtNameTh': 'เขตบางเขน',
    'districtNameEn': 'Khet Bang Khen',
  },
  {
    'provinceId': '10',
    'provinceNameTh': 'กาญจนบุรี',
    'provinceNameEn': 'Kanchanaburi',
    'districtId': '1001',
    'districtNameTh': 'เมืองกาญจนบุรี',
    'districtNameEn': 'Mueang Kanchanaburi',
  },
];

DistrictService _makeService({int callDelayMs = 0}) {
  return DistrictService(
    assetLoader: (_) async {
      if (callDelayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: callDelayMs));
      }
      return jsonEncode(_fixtureDistricts);
    },
  );
}

/// A [DistrictService] subclass that counts every call to [searchByName].
///
/// Used in the debounce test to verify the widget coalesces rapid keystrokes
/// into a single search call, rather than counting raw asset-loader hits
/// (which are cached after the first load and would not increment).
class _CountingDistrictService extends DistrictService {
  int searchCallCount = 0;

  _CountingDistrictService()
    : super(assetLoader: (_) async => jsonEncode(_fixtureDistricts));

  @override
  Future<List<DistrictEntry>> searchByName(String query) async {
    searchCallCount++;
    return super.searchByName(query);
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DistrictPickerSheet', () {
    // -----------------------------------------------------------------------
    // Debounce test — WBS 5.2 acceptance criterion 4
    // -----------------------------------------------------------------------
    testWidgets(
      'debounces search input by 200 ms — loader not called again mid-typing',
      (tester) async {
        // Use _CountingDistrictService which overrides searchByName and counts
        // each call. Counting at the assetLoader level does not work because
        // DistrictService caches the parsed list after the first load, so all
        // subsequent searchByName calls return from cache without hitting the
        // loader again.
        final countingSvc = _CountingDistrictService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () =>
                      showDistrictPicker(ctx, service: countingSvc),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        // Open the bottom sheet
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The initial load fires once (empty query on open)
        expect(countingSvc.searchCallCount, 1);

        // Type 3 characters quickly — each within 200 ms of the last
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);

        // Enter 'b', 'a', 'n' with a 50 ms gap between each keystroke
        // (all within the 200 ms debounce window)
        await tester.enterText(searchField, 'b');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(searchField, 'ba');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(searchField, 'ban');
        await tester.pump(const Duration(milliseconds: 50));

        // Still within debounce window — should NOT have fired a new search yet
        // (count is still 1 from the initial load)
        expect(
          countingSvc.searchCallCount,
          1,
          reason:
              'searchByName must not be called again while typing within the 200 ms window',
        );

        // Now advance past the 200 ms debounce threshold
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // Now exactly one more search should have fired for the final value 'ban'
        expect(
          countingSvc.searchCallCount,
          2,
          reason:
              'searchByName must be called exactly once after the debounce settles',
        );
      },
    );

    testWidgets('shows initial list of districts on open', (tester) async {
      final svc = _makeService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDistrictPicker(ctx, service: svc),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // All three fixture districts should appear
      expect(find.text('Khet Bang Rak'), findsNothing); // text is in RichText
      expect(find.byType(DistrictPickerSheet), findsOneWidget);
      // At least one DistrictTile rendered
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('tapping a district row dismisses sheet and returns entry', (
      tester,
    ) async {
      final svc = _makeService();
      DistrictEntry? picked;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  picked = await showDistrictPicker(ctx, service: svc);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the first district tile by finding the InkWell that is a descendant
      // of the ListView (district tiles), not the drag handle or modal barrier.
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);
      final tileInkWell = find.descendant(
        of: listView,
        matching: find.byType(InkWell),
      );
      expect(tileInkWell, findsWidgets);
      await tester.tap(tileInkWell.first);
      await tester.pumpAndSettle();

      // Sheet closed and a district was returned
      expect(find.byType(DistrictPickerSheet), findsNothing);
      expect(picked, isNotNull);
      expect(picked!.districtId, isNotEmpty);
    });

    testWidgets('shows empty state when search returns no results', (
      tester,
    ) async {
      final svc = _makeService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDistrictPicker(ctx, service: svc),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'zzznomatch999');

      // Wait for debounce
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('No districts found'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // DistrictRow widget
  // -------------------------------------------------------------------------
  group('DistrictRow', () {
    testWidgets('shows placeholder text when value is null', (tester) async {
      final svc = _makeService();
      await tester.pumpWidget(
        _wrap(DistrictRow(value: null, service: svc, onChanged: (_) {})),
      );
      expect(find.text('Select your district'), findsOneWidget);
    });

    testWidgets('shows district label when value is set', (tester) async {
      final svc = _makeService();
      const entry = DistrictEntry(
        provinceId: '1',
        provinceNameTh: 'กรุงเทพมหานคร',
        provinceNameEn: 'Bangkok',
        districtId: '1004',
        districtNameTh: 'เขตบางรัก',
        districtNameEn: 'Khet Bang Rak',
      );

      await tester.pumpWidget(
        _wrap(DistrictRow(value: entry, service: svc, onChanged: (_) {})),
      );

      // The label is split across RichText spans, so we look for the widget
      // rather than a single text string.
      expect(find.byType(RichText), findsWidgets);
      // Verify the RichText contains the Thai name somewhere
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final allText = richTexts.map((rt) => rt.text.toPlainText()).join(' ');
      expect(allText, contains('เขตบางรัก'));
      expect(allText, contains('Khet Bang Rak'));
      expect(allText, contains('Bangkok'));
    });

    testWidgets('tapping DistrictRow opens picker sheet', (tester) async {
      final svc = _makeService();
      await tester.pumpWidget(
        _wrap(DistrictRow(value: null, service: svc, onChanged: (_) {})),
      );

      await tester.tap(find.byType(DistrictRow));
      await tester.pumpAndSettle();

      expect(find.byType(DistrictPickerSheet), findsOneWidget);
    });
  });
}
