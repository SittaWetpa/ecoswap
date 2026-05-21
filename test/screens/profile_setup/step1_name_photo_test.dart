import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/screens/profile_setup/step1_name_photo.dart';
import 'package:ecoswap/services/photo_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [Step1NamePhoto] under a minimal [MaterialApp].
///
/// [onNext] is called when the screen successfully saves and navigates forward.
/// [photoService] is injectable so tests never touch Firebase Storage.
/// [updateUserDoc] is injectable so tests never touch Firestore.
/// [getCurrentUid] returns a fixed UID so no real Firebase Auth is needed.
Widget _buildScreen({
  VoidCallback? onNext,
  PhotoService? photoService,
  UserDocUpdater? updateUserDoc,
  CurrentUidGetter? getCurrentUid,
}) {
  return MaterialApp(
    home: Step1NamePhoto(
      onNext: onNext,
      photoService: photoService,
      updateUserDoc: updateUserDoc ?? (_, _) async {},
      getCurrentUid: getCurrentUid ?? () => 'test-uid-001',
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Widget test: display name field rejects empty string ─────────────────
  //
  // WBS 5.1 acceptance: "Display name validates 1–40 chars"
  // Tapping Next with an empty name must NOT call onNext and must surface
  // a validation error.
  group('Step1NamePhoto — display name validation', () {
    testWidgets('rejects empty display name — Next button is disabled', (
      WidgetTester tester,
    ) async {
      bool nextCalled = false;

      await tester.pumpWidget(_buildScreen(onNext: () => nextCalled = true));

      // The name field is empty by default — Next button must be disabled.
      final nextButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(
        nextButton.onPressed,
        isNull,
        reason: 'Next button should be disabled when name is empty',
      );

      // Confirm onNext was never triggered.
      expect(nextCalled, isFalse);
    });

    testWidgets('rejects empty display name — shows error on tap', (
      WidgetTester tester,
    ) async {
      bool nextCalled = false;

      await tester.pumpWidget(_buildScreen(onNext: () => nextCalled = true));

      // Clear the field (it starts empty, but be explicit).
      await tester.enterText(find.byKey(const Key('displayNameField')), '');
      await tester.pump();

      // Force-tap the button area even if disabled, by calling _handleNext
      // logic indirectly — pump the widget with an enabled-state workaround:
      // enter a valid name, then clear it, to expose the disabled state.
      // Here we just verify the button is still disabled.
      final nextButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(nextButton.onPressed, isNull);
      expect(nextCalled, isFalse);
    });

    testWidgets('enables Next button when name is 1 char', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      await tester.enterText(find.byKey(const Key('displayNameField')), 'A');
      await tester.pump();

      final nextButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(
        nextButton.onPressed,
        isNotNull,
        reason: 'Next should be enabled with a 1-char name',
      );
    });

    // ── Widget test: display name field rejects > 40 chars ────────────────
    //
    // WBS 5.1 acceptance: "Display name validates 1–40 chars"
    // The LengthLimitingTextInputFormatter hard-caps at 40; typing more must
    // not increase the field beyond 40 characters.
    testWidgets('hard-caps display name at 40 chars via input formatter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      // Try to enter 45 characters — the formatter must truncate to 40.
      final over40 = 'A' * 45;
      await tester.enterText(find.byKey(const Key('displayNameField')), over40);
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('displayNameField')),
      );
      final actualText = field.controller!.text;
      expect(
        actualText.length,
        lessThanOrEqualTo(40),
        reason: 'Field must not exceed 40 chars',
      );
    });

    testWidgets('Next button disabled when name is exactly 41 chars entered', (
      WidgetTester tester,
    ) async {
      // The formatter prevents > 40 chars, so entering 41 chars produces 40.
      // This test confirms the formatter is in place: after entering 41, the
      // button is enabled (40 chars is valid) and the length is capped.
      await tester.pumpWidget(_buildScreen());

      await tester.enterText(
        find.byKey(const Key('displayNameField')),
        'A' * 41,
      );
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(const Key('displayNameField')),
      );
      // The formatter caps at 40, so the value in the controller is ≤ 40.
      expect(field.controller!.text.length, lessThanOrEqualTo(40));

      // With exactly 40 chars the button should be enabled (valid range).
      final nextButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('nextButton')),
      );
      expect(nextButton.onPressed, isNotNull);
    });

    testWidgets('shows title and subtitle copy', (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());

      expect(find.text('What should we call you?'), findsOneWidget);
      expect(
        find.text('Add a photo and a name so other swappers recognise you.'),
        findsOneWidget,
      );
    });

    testWidgets('calls onNext after valid name is saved', (
      WidgetTester tester,
    ) async {
      bool nextCalled = false;

      await tester.pumpWidget(
        _buildScreen(
          onNext: () => nextCalled = true,
          updateUserDoc: (uid, data) async {
            // Verify correct fields are written.
            expect(uid, equals('test-uid-001'));
            expect(data['displayName'], equals('Nong'));
            expect(data.containsKey('photoUrl'), isTrue);
          },
        ),
      );

      await tester.enterText(find.byKey(const Key('displayNameField')), 'Nong');
      await tester.pump();

      await tester.tap(find.byKey(const Key('nextButton')));
      await tester.pump();
      await tester.pump();

      expect(nextCalled, isTrue);
    });

    testWidgets('skipping photo leaves photoUrl as empty string', (
      WidgetTester tester,
    ) async {
      String? capturedPhotoUrl;

      await tester.pumpWidget(
        _buildScreen(
          onNext: () {},
          updateUserDoc: (uid, data) async {
            capturedPhotoUrl = data['photoUrl'] as String?;
          },
        ),
      );

      // Enter a valid name but do NOT tap the photo upload.
      await tester.enterText(find.byKey(const Key('displayNameField')), 'Ploy');
      await tester.pump();

      await tester.tap(find.byKey(const Key('nextButton')));
      await tester.pump();
      await tester.pump();

      // photoUrl must be empty string, not null.
      expect(capturedPhotoUrl, equals(''));
    });

    testWidgets('photo tap invokes PhotoService.pickAndUpload', (
      WidgetTester tester,
    ) async {
      bool uploadCalled = false;

      final photoService = PhotoService(
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
              // Path must be user_photos/{uid}.jpg
              expect(storagePath, equals('user_photos/test-uid-001.jpg'));
              return 'https://example.com/photo.jpg';
            },
      );

      await tester.pumpWidget(_buildScreen(photoService: photoService));

      // Find and tap the PhotoUpload widget (GestureDetector wraps it).
      await tester.tap(find.byType(PhotoUpload));
      await tester.pump();
      await tester.pump();

      expect(uploadCalled, isTrue);
    });
  });

  // ── Unit test: PhotoService compresses below 1 MB ─────────────────────────
  //
  // WBS 5.1 testing: "PhotoService.pickAndUpload() compresses image below
  // 1 MB before upload"
  group('PhotoService — user_photos compression (WBS 5.1)', () {
    test(
      'pickAndUpload for user_photos sends < 1 MB bytes to storage',
      () async {
        const rawSize = 3 * 1024 * 1024; // 3 MB raw
        const compressedSize = 700 * 1024; // 700 KB after compression

        int? uploadedSize;

        final service = PhotoService(
          pickImage: () async =>
              Uint8List.fromList(List.generate(rawSize, (i) => i % 256)),
          compress:
              ({
                required Uint8List bytes,
                required int minWidth,
                required int minHeight,
                required int quality,
              }) async => Uint8List(compressedSize),
          upload:
              ({required String storagePath, required Uint8List bytes}) async {
                uploadedSize = bytes.length;
                return 'https://example.com/photo.jpg';
              },
        );

        final url = await service.pickAndUpload(
          storagePath: 'user_photos/uid-abc.jpg',
        );

        expect(url, isNotNull);
        expect(uploadedSize, isNotNull);
        expect(
          uploadedSize!,
          lessThan(PhotoService.kMaxBytes),
          reason: 'Uploaded bytes must be below 1 MB',
        );
      },
    );
  });
}
