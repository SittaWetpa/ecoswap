import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ecoswap/models/user.dart' as app_user;
import 'package:ecoswap/providers/auth_provider.dart' as auth_prov;
import 'package:ecoswap/screens/profile/edit_profile_screen.dart';
import 'package:ecoswap/screens/profile/profile_screen.dart';
import 'package:ecoswap/services/district_service.dart';
import 'package:ecoswap/services/photo_service.dart';
import 'package:ecoswap/widgets/impact_stat_strip.dart';

// ---------------------------------------------------------------------------
// Fake Firebase Auth — never talks to Firebase
// ---------------------------------------------------------------------------

class _FakeFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  final _controller = StreamController<firebase_auth.User?>.broadcast();

  @override
  firebase_auth.User? get currentUser => null;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _controller.stream;

  @override
  Future<void> signOut() async => _controller.add(null);

  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Fixture user — used across multiple tests
// ---------------------------------------------------------------------------

final _fixtureUser = app_user.User(
  uid: 'uid-test-001',
  email: 'nong@example.com',
  displayName: 'Nong',
  photoUrl: '',
  homeDistrict: const app_user.HomeDistrict(
    provinceId: '10',
    provinceNameTh: 'กรุงเทพมหานคร',
    provinceNameEn: 'Bangkok',
    districtId: '1023',
    districtNameTh: 'บางมด',
    districtNameEn: 'Bang Mod',
  ),
  bio: 'KMUTT student, decluttering before the semester ends.',
  tradesCount: 7,
  totalCo2Saved: 47.5,
  totalWasteDiverted: 12.3,
);

// ---------------------------------------------------------------------------
// Helpers — build widgets under test
// ---------------------------------------------------------------------------

/// Builds [ProfileScreen] with a stubbed reader that emits the fixture user's
/// JSON map directly — no Firestore sealed classes required.
Widget _buildProfileScreen({
  app_user.User? user,
  VoidCallback? onMyItems,
  VoidCallback? onHowItWorks,
}) {
  final fakeAuth = _FakeFirebaseAuth();
  final provider = auth_prov.AuthProvider(firebaseAuth: fakeAuth);

  // Inject a plain Stream<Map?> so tests never touch the sealed DocumentSnapshot.
  Stream<Map<String, dynamic>?> fakeReader(String uid) {
    final data = user?.toJson();
    return Stream.value(data);
  }

  return ChangeNotifierProvider<auth_prov.AuthProvider>.value(
    value: provider,
    child: MaterialApp(
      home: ProfileScreen(
        userDocReader: fakeReader,
        getCurrentUid: () => 'uid-test-001',
        onMyItems: onMyItems,
        onHowItWorks: onHowItWorks,
      ),
    ),
  );
}

/// Builds [EditProfileScreen] under a minimal [MaterialApp].
Widget _buildEditScreen({
  app_user.User? initialUser,
  UserDocUpdater? updateUserDoc,
  String? Function()? getCurrentUid,
  PhotoService? photoService,
  DistrictService? districtService,
  VoidCallback? onSaved,
}) {
  return MaterialApp(
    home: EditProfileScreen(
      initialUser: initialUser,
      updateUserDoc: updateUserDoc ?? (a, b) async {},
      getCurrentUid: getCurrentUid ?? () => 'uid-test-001',
      photoService: photoService,
      districtService: districtService ?? _stubDistrictService(),
      onSaved: onSaved,
    ),
  );
}

/// A [DistrictService] backed by an empty JSON array — no asset bundle needed.
DistrictService _stubDistrictService() {
  return DistrictService(assetLoader: (_) async => '[]');
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // ── WBS 5.4 Testing requirement 1:
  //    Widget test: view screen renders all 6 fields
  // ---------------------------------------------------------------------------
  group('ProfileScreen (view mode) — renders all profile fields', () {
    testWidgets('displays display name', (tester) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      expect(find.text('Nong'), findsWidgets);
    });

    testWidgets('displays district in Thai · English, Province format', (
      tester,
    ) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      // Acceptance criterion: district format "Thai · English, Province"
      expect(
        find.text('บางมด · Bang Mod, Bangkok'),
        findsOneWidget,
        reason: 'District must render as "Thai · English, Province"',
      );
    });

    testWidgets('displays impact summary strip with swaps, CO2, waste', (
      tester,
    ) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      // Impact strip must be present (key)
      expect(find.byKey(const Key('impactSummary')), findsOneWidget);

      // Swaps count
      expect(find.text('7'), findsWidgets);

      // CO2 — 47.5 formatted with 1 decimal
      expect(find.text('47.5'), findsWidgets);

      // Waste — 12.3
      expect(find.text('12.3'), findsWidgets);

      // Labels
      expect(find.text('Swaps'), findsOneWidget);
      expect(find.text('kg CO₂'), findsOneWidget);
      expect(find.text('kg waste'), findsOneWidget);
    });

    testWidgets('displays bio text', (tester) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      expect(
        find.text('KMUTT student, decluttering before the semester ends.'),
        findsOneWidget,
      );
    });

    testWidgets('displays Edit profile button', (tester) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      expect(find.byKey(const Key('editProfileButton')), findsOneWidget);
    });

    testWidgets('displays Log out button', (tester) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      expect(find.byKey(const Key('logoutButton')), findsOneWidget);
    });

    testWidgets('"How it works" row is shown and invokes onHowItWorks', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _buildProfileScreen(
          user: _fixtureUser,
          onHowItWorks: () => tapped = true,
        ),
      );
      await tester.pump();

      final row = find.byKey(const Key('howItWorksRow'));
      expect(row, findsOneWidget);
      expect(find.text('How it works'), findsOneWidget);

      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      expect(tapped, isTrue);
    });

    // All 6 fields in one test — display name, district, 3 impact stats, bio
    testWidgets(
      'renders all 6 fields (display name + district + 3 stats + bio)',
      (tester) async {
        await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
        await tester.pump();

        // 1. Display name
        expect(find.byKey(const Key('profileDisplayName')), findsOneWidget);
        // 2. District
        expect(find.byKey(const Key('profileDistrict')), findsOneWidget);
        // 3–5. Impact summary (3 SummaryStat widgets inside the strip)
        expect(find.byKey(const Key('impactSummary')), findsOneWidget);
        final statWidgets = find.byType(SummaryStat);
        expect(statWidgets, findsNWidgets(3));
        // 6. Bio
        expect(find.byKey(const Key('profileBio')), findsOneWidget);
      },
    );

    testWidgets('top bar shows title only — no cog or info icon', (
      tester,
    ) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      // Title present
      expect(find.text('Profile'), findsOneWidget);

      // No settings/cog icon
      expect(
        find.byIcon(Icons.settings),
        findsNothing,
        reason: 'Cog/settings icon must not appear on Profile top bar',
      );
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
      expect(
        find.byIcon(Icons.info),
        findsNothing,
        reason: 'Info icon must not appear on Profile top bar',
      );
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('no age, no verification badge, no activity status shown', (
      tester,
    ) async {
      await tester.pumpWidget(_buildProfileScreen(user: _fixtureUser));
      await tester.pump();

      // Check for "Age" as a label — not lowercase "age" which appears in
      // unrelated words like "manage".
      expect(find.textContaining('Age'), findsNothing);
      expect(find.textContaining('Verified'), findsNothing);
      expect(find.textContaining('verified'), findsNothing);
      expect(find.textContaining('active now'), findsNothing);
      expect(find.textContaining('Active now'), findsNothing);
      expect(find.textContaining('last seen'), findsNothing);
    });
  });

  // ── WBS 5.4 Testing requirement 2:
  //    Widget test: edit screen pre-fills correctly from a fixture user
  // ---------------------------------------------------------------------------
  group('EditProfileScreen — pre-fills correctly', () {
    testWidgets('display name field is pre-filled with fixture user name', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      // _EpTextField is a StatefulWidget wrapping a TextField; find the
      // TextField descendant instead of casting the keyed widget directly.
      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('displayNameField')),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.controller?.text, equals('Nong'));
    });

    testWidgets('bio field is pre-filled with fixture user bio', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      // _EpTextArea wraps a TextField; find the descendant.
      final bioField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('bioField')),
          matching: find.byType(TextField),
        ),
      );
      expect(
        bioField.controller?.text,
        equals('KMUTT student, decluttering before the semester ends.'),
      );
    });

    testWidgets('district row shows pre-filled district in correct format', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      // DistrictRow renders via RichText/TextSpan; use byWidgetPredicate to
      // inspect the plain-text of the span tree directly.
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('บางมด'),
        ),
        findsWidgets,
        reason: 'DistrictRow must show pre-filled Thai district name',
      );
    });

    testWidgets('char counter initialises to the bio length', (tester) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      final bioLength =
          'KMUTT student, decluttering before the semester ends.'.length;
      expect(find.text('$bioLength/140'), findsOneWidget);
    });

    testWidgets('top bar shows "Edit profile" title with back arrow', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('Save button is enabled when fixture user is pre-filled', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('saveButton')),
      );
      expect(
        saveButton.onPressed,
        isNotNull,
        reason: 'Save should be enabled when fields are valid',
      );
    });
  });

  // ── WBS 5.4 Testing requirement 3:
  //    Widget test: save triggers a Firestore update with the merged document
  // ---------------------------------------------------------------------------
  group('EditProfileScreen — save writes to Firestore', () {
    testWidgets('save calls updateUserDoc with displayName, bio, photoUrl', (
      tester,
    ) async {
      String? capturedUid;
      Map<String, dynamic>? capturedData;

      await tester.pumpWidget(
        _buildEditScreen(
          initialUser: _fixtureUser,
          updateUserDoc: (uid, data) async {
            capturedUid = uid;
            capturedData = data;
          },
          onSaved: () {},
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pump();
      await tester.pump();

      expect(capturedUid, equals('uid-test-001'));
      expect(capturedData, isNotNull);
      expect(capturedData!['displayName'], equals('Nong'));
      expect(
        capturedData!['bio'],
        equals('KMUTT student, decluttering before the semester ends.'),
      );
      expect(capturedData!.containsKey('photoUrl'), isTrue);
    });

    testWidgets('save includes homeDistrict when a district is set', (
      tester,
    ) async {
      Map<String, dynamic>? capturedData;

      await tester.pumpWidget(
        _buildEditScreen(
          initialUser: _fixtureUser,
          updateUserDoc: (_, data) async {
            capturedData = data;
          },
          onSaved: () {},
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pump();
      await tester.pump();

      // homeDistrict must be present with all 6 fields (WBS 3.6)
      expect(capturedData, isNotNull);
      final district = capturedData!['homeDistrict'] as Map<String, dynamic>?;
      expect(district, isNotNull);
      expect(district!['districtId'], equals('1023'));
      expect(district['districtNameTh'], equals('บางมด'));
      expect(district['districtNameEn'], equals('Bang Mod'));
      expect(district['provinceNameEn'], equals('Bangkok'));
    });

    testWidgets('save button disabled when display name is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      // Clear the display name
      await tester.enterText(find.byKey(const Key('displayNameField')), '');
      await tester.pump();

      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('saveButton')),
      );
      expect(
        saveButton.onPressed,
        isNull,
        reason: 'Save must be disabled when display name is empty',
      );
    });

    testWidgets('bio is clamped to 140 chars by TextField maxLength', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      // Enter 141 chars — TextField maxLength clamps to 140.
      final longBio = 'A' * 141;
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('bioField')),
          matching: find.byType(TextField),
        ),
        longBio,
      );
      await tester.pump();

      final bioField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('bioField')),
          matching: find.byType(TextField),
        ),
      );
      expect(
        bioField.controller!.text.length,
        lessThanOrEqualTo(140),
        reason: 'Bio must not exceed 140 chars',
      );
    });

    testWidgets('calls onSaved callback after successful save', (tester) async {
      bool savedCalled = false;

      await tester.pumpWidget(
        _buildEditScreen(
          initialUser: _fixtureUser,
          updateUserDoc: (_, a) async {},
          onSaved: () => savedCalled = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pump();
      await tester.pump();

      expect(savedCalled, isTrue);
    });
  });

  // ── No banned UI elements in edit screen
  // ---------------------------------------------------------------------------
  group('EditProfileScreen — no banned UI elements', () {
    testWidgets('no age, verification, or activity status fields shown', (
      tester,
    ) async {
      await tester.pumpWidget(_buildEditScreen(initialUser: _fixtureUser));
      await tester.pump();

      expect(find.textContaining('Age'), findsNothing);
      expect(find.textContaining('Verified'), findsNothing);
      expect(find.textContaining('active now'), findsNothing);
      expect(find.textContaining('trust'), findsNothing);
    });
  });

  // ── Photo service integration in edit screen
  // ---------------------------------------------------------------------------
  group('EditProfileScreen — photo change', () {
    testWidgets('tapping Change photo invokes PhotoService.pickAndUpload', (
      tester,
    ) async {
      bool uploadCalled = false;

      final fakePhotoService = PhotoService(
        pickImage: () async {
          uploadCalled = true;
          return Uint8List.fromList([1, 2, 3]);
        },
        compress:
            ({
              required Uint8List bytes,
              required int minWidth,
              required int minHeight,
              required int quality,
            }) async => Uint8List.fromList([1, 2, 3]),
        upload:
            ({required String storagePath, required Uint8List bytes}) async {
              expect(storagePath, equals('user_photos/uid-test-001.jpg'));
              // Return empty URL to avoid NetworkImage in widget tests.
              return '';
            },
      );

      await tester.pumpWidget(
        _buildEditScreen(
          initialUser: _fixtureUser,
          photoService: fakePhotoService,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('changePhotoButton')));
      await tester.pump();
      await tester.pump();

      expect(uploadCalled, isTrue);
    });
  });
}
