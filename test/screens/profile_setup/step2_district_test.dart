import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/screens/profile_setup/step2_district.dart';
import 'package:ecoswap/services/district_service.dart';
import 'package:ecoswap/widgets/district_picker.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal JSON fixture — one Bangkok district so tests don't need real assets.
const _kFakeJson = '''[
  {
    "provinceId": "10",
    "provinceNameTh": "กรุงเทพมหานคร",
    "provinceNameEn": "Bangkok",
    "districtId": "1001",
    "districtNameTh": "บางมด",
    "districtNameEn": "Bang Mod"
  }
]''';

/// [DistrictService] backed by the fixture — no asset bundle required.
DistrictService _fakeService() =>
    DistrictService(assetLoader: (_) async => _kFakeJson);

/// Builds [Step2District] under a minimal [MaterialApp].
Widget _buildScreen({
  VoidCallback? onNext,
  VoidCallback? onBack,
  DistrictService? service,
  UserDocUpdater? updateUserDoc,
  CurrentUidGetter? getCurrentUid,
}) {
  return MaterialApp(
    home: Step2District(
      onNext: onNext,
      onBack: onBack,
      districtService: service ?? _fakeService(),
      updateUserDoc: updateUserDoc ?? (_, _) async {},
      getCurrentUid: getCurrentUid ?? () => 'test-uid-001',
    ),
  );
}

/// Picks the single district in the fixture via the bottom sheet.
///
/// Taps [DistrictRow] to open the sheet, waits for results, then taps the
/// first (only) tile.
Future<void> _pickDistrict(WidgetTester tester) async {
  await tester.tap(find.byType(DistrictRow));
  await tester.pumpAndSettle();
  // _DistrictTile renders via RichText with full label "บางมด · Bang Mod, Bangkok".
  // find.text() does exact matching; find.textContaining() does substring matching.
  await tester.tap(find.textContaining('บางมด', findRichText: true).last);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Next button disabled until a district is selected ─────────────────────
  group('Step2District — Next button state', () {
    testWidgets('Next button is disabled before any district is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(btn.onPressed, isNull,
          reason: 'Next must be disabled with no district selected');
    });

    testWidgets('Next button is enabled after a district is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await _pickDistrict(tester);

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(btn.onPressed, isNotNull,
          reason: 'Next must be enabled once a district is picked');
    });
  });

  // ── Selecting a district writes all six fields to homeDistrict ────────────
  //
  // WBS 5.2 acceptance: "Selecting a district writes all six fields to
  // /users/{uid}.homeDistrict — no missing fields, no extra fields"
  group('Step2District — Firestore write on Next', () {
    testWidgets('writes all six homeDistrict fields to /users/{uid}',
        (WidgetTester tester) async {
      String? capturedUid;
      Map<String, dynamic>? capturedData;

      await tester.pumpWidget(_buildScreen(
        onNext: () {},
        updateUserDoc: (uid, data) async {
          capturedUid = uid;
          capturedData = data;
        },
      ));

      await _pickDistrict(tester);
      await tester.tap(find.byKey(const Key('nextButton')));
      await tester.pumpAndSettle();

      expect(capturedUid, equals('test-uid-001'));
      expect(capturedData, isNotNull);

      final hd = capturedData!['homeDistrict'] as Map<String, dynamic>;

      // Exactly six fields — no missing, no extra.
      expect(hd.keys.toSet(), equals({
        'provinceId',
        'provinceNameTh',
        'provinceNameEn',
        'districtId',
        'districtNameTh',
        'districtNameEn',
      }));

      // All values are non-empty strings.
      for (final entry in hd.entries) {
        expect(entry.value, isA<String>(),
            reason: '${entry.key} must be a String');
        expect((entry.value as String).isNotEmpty,
            isTrue, reason: '${entry.key} must not be empty');
      }
    });

    testWidgets('writes correct district values for the selected entry',
        (WidgetTester tester) async {
      Map<String, dynamic>? capturedHomeDistrict;

      await tester.pumpWidget(_buildScreen(
        onNext: () {},
        updateUserDoc: (uid, data) async {
          capturedHomeDistrict =
              data['homeDistrict'] as Map<String, dynamic>;
        },
      ));

      await _pickDistrict(tester);
      await tester.tap(find.byKey(const Key('nextButton')));
      await tester.pumpAndSettle();

      expect(capturedHomeDistrict!['provinceId'], equals('10'));
      expect(capturedHomeDistrict!['provinceNameTh'], equals('กรุงเทพมหานคร'));
      expect(capturedHomeDistrict!['provinceNameEn'], equals('Bangkok'));
      expect(capturedHomeDistrict!['districtId'], equals('1001'));
      expect(capturedHomeDistrict!['districtNameTh'], equals('บางมด'));
      expect(capturedHomeDistrict!['districtNameEn'], equals('Bang Mod'));
    });

    testWidgets('calls onNext after Firestore write succeeds',
        (WidgetTester tester) async {
      bool nextCalled = false;

      await tester.pumpWidget(_buildScreen(
        onNext: () => nextCalled = true,
        updateUserDoc: (_, _) async {},
      ));

      await _pickDistrict(tester);
      await tester.tap(find.byKey(const Key('nextButton')));
      await tester.pumpAndSettle();

      expect(nextCalled, isTrue);
    });
  });

  // ── AreaSelected confirmation state ───────────────────────────────────────
  //
  // WBS 5.2 prototype: setup.jsx AreaSelected (lines 135-162) — shows a
  // confirmation card with "Change" button and a "nearby districts" info note.
  group('Step2District — AreaSelected state', () {
    testWidgets('shows Change button and info note after district is picked',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await _pickDistrict(tester);

      // Change button must be visible.
      expect(find.byKey(const Key('changeDistrictButton')), findsOneWidget);

      // Info note must mention the district's English name.
      expect(
        find.textContaining('Bang Mod'),
        findsWidgets,
        reason: 'Info note must reference the selected district English name',
      );
      expect(
        find.textContaining('nearby districts'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Change resets to picker state',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await _pickDistrict(tester);

      // Confirm we are in the selected state.
      expect(find.byKey(const Key('changeDistrictButton')), findsOneWidget);

      // Tap Change — should go back to the DistrictRow search affordance.
      await tester.tap(find.byKey(const Key('changeDistrictButton')));
      await tester.pumpAndSettle();

      expect(find.byType(DistrictRow), findsOneWidget);
      expect(find.byKey(const Key('changeDistrictButton')), findsNothing);

      // Next button must be disabled again.
      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(btn.onPressed, isNull);
    });
  });

  // ── Screen copy ───────────────────────────────────────────────────────────
  group('Step2District — copy', () {
    testWidgets('shows correct title and subtitle',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Where are you based?'), findsOneWidget);
      expect(find.textContaining('No GPS needed'), findsOneWidget);
    });
  });
}
