import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/screens/profile_setup/step3_bio.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [Step3Bio] under a minimal [MaterialApp].
///
/// [onDone] is called when the screen successfully saves and navigates forward.
/// [updateUserDoc] is injectable so tests never touch Firestore.
/// [getCurrentUid] returns a fixed UID so no real Firebase Auth is needed.
Widget _buildScreen({
  VoidCallback? onDone,
  VoidCallback? onBack,
  UserDocUpdater? updateUserDoc,
  CurrentUidGetter? getCurrentUid,
}) {
  return MaterialApp(
    home: Step3Bio(
      onDone: onDone,
      onBack: onBack,
      updateUserDoc: updateUserDoc ?? (_, _) async {},
      getCurrentUid: getCurrentUid ?? () => 'test-uid-001',
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Widget test: typing 141 chars is truncated at 140 ─────────────────────
  //
  // WBS 5.3 testing: "Widget test: typing 141 chars is truncated at 140"
  // The LengthLimitingTextInputFormatter hard-caps at 140; typing more must
  // not increase the field beyond 140 characters.
  group('Step3Bio — character limit', () {
    testWidgets('typing 141 chars is truncated at 140', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      // Try to enter 141 characters — the formatter must truncate to 140.
      final over140 = 'A' * 141;
      await tester.enterText(find.byKey(const Key('bioField')), over140);
      await tester.pump();

      final field = tester.widget<TextField>(find.byKey(const Key('bioField')));
      final actualLength = field.controller!.text.length;
      expect(
        actualLength,
        equals(140),
        reason: 'Bio field must be hard-capped at 140 chars',
      );
    });

    testWidgets('entering exactly 140 chars is allowed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      final exactly140 = 'B' * 140;
      await tester.enterText(find.byKey(const Key('bioField')), exactly140);
      await tester.pump();

      final field = tester.widget<TextField>(find.byKey(const Key('bioField')));
      expect(field.controller!.text.length, equals(140));
    });
  });

  // ── Widget test: counter updates correctly at 0, 70, 140 ─────────────────
  //
  // WBS 5.3 testing: "Widget test: counter updates correctly at 0, 70, 140"
  group('Step3Bio — live character counter', () {
    testWidgets('counter shows "0 / 140" when bio is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(
        find.text('0 / 140'),
        findsOneWidget,
        reason: 'Counter must start at "0 / 140"',
      );
    });

    testWidgets('counter shows "70 / 140" after typing 70 chars', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      await tester.enterText(find.byKey(const Key('bioField')), 'C' * 70);
      await tester.pump();

      expect(
        find.text('70 / 140'),
        findsOneWidget,
        reason: 'Counter must update to "70 / 140" after 70 chars',
      );
    });

    testWidgets('counter shows "140 / 140" after typing 140 chars', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      await tester.enterText(find.byKey(const Key('bioField')), 'D' * 140);
      await tester.pump();

      expect(
        find.text('140 / 140'),
        findsOneWidget,
        reason: 'Counter must update to "140 / 140" at cap',
      );
    });

    testWidgets('counter updates live as user types', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      // Start at 0
      expect(find.text('0 / 140'), findsOneWidget);

      // Type 10 chars
      await tester.enterText(find.byKey(const Key('bioField')), 'E' * 10);
      await tester.pump();
      expect(find.text('10 / 140'), findsOneWidget);

      // Type 50 chars
      await tester.enterText(find.byKey(const Key('bioField')), 'E' * 50);
      await tester.pump();
      expect(find.text('50 / 140'), findsOneWidget);
    });
  });

  // ── Empty bio is allowed ──────────────────────────────────────────────────
  //
  // WBS 5.3 acceptance: "Empty bio is allowed and writes empty string to
  // /users/{uid}.bio"
  group('Step3Bio — empty bio behaviour', () {
    testWidgets('Start swapping button is enabled when bio is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.byKey(const Key('startSwappingButton')),
      );
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Button must be enabled even with empty bio',
      );
    });

    testWidgets('tapping Start swapping with empty bio writes empty string', (
      WidgetTester tester,
    ) async {
      String? capturedBio;

      await tester.pumpWidget(
        _buildScreen(
          onDone: () {},
          updateUserDoc: (uid, data) async {
            capturedBio = data['bio'] as String?;
          },
        ),
      );

      // Do NOT type anything — bio is empty.
      await tester.tap(find.byKey(const Key('startSwappingButton')));
      await tester.pump();
      await tester.pump();

      expect(
        capturedBio,
        equals(''),
        reason: 'Empty bio must write empty string, not null',
      );
    });

    testWidgets('Skip button writes empty string when bio is untouched', (
      WidgetTester tester,
    ) async {
      String? capturedBio;

      await tester.pumpWidget(
        _buildScreen(
          onDone: () {},
          updateUserDoc: (uid, data) async {
            capturedBio = data['bio'] as String?;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('skipButton')));
      await tester.pump();
      await tester.pump();

      expect(capturedBio, equals(''));
    });
  });

  // ── Firestore write ───────────────────────────────────────────────────────
  group('Step3Bio — Firestore write on done', () {
    testWidgets('writes bio text to /users/{uid} on Start swapping', (
      WidgetTester tester,
    ) async {
      String? capturedUid;
      Map<String, dynamic>? capturedData;

      await tester.pumpWidget(
        _buildScreen(
          onDone: () {},
          updateUserDoc: (uid, data) async {
            capturedUid = uid;
            capturedData = data;
          },
        ),
      );

      const bioText = 'KMUTT student, decluttering before the semester ends.';
      await tester.enterText(find.byKey(const Key('bioField')), bioText);
      await tester.pump();

      await tester.tap(find.byKey(const Key('startSwappingButton')));
      await tester.pump();
      await tester.pump();

      expect(capturedUid, equals('test-uid-001'));
      expect(capturedData, isNotNull);
      expect(capturedData!['bio'], equals(bioText));
    });

    testWidgets('calls onDone after Firestore write succeeds', (
      WidgetTester tester,
    ) async {
      bool doneCalled = false;

      await tester.pumpWidget(
        _buildScreen(
          onDone: () => doneCalled = true,
          updateUserDoc: (_, _) async {},
        ),
      );

      await tester.tap(find.byKey(const Key('startSwappingButton')));
      await tester.pump();
      await tester.pump();

      expect(doneCalled, isTrue);
    });
  });

  // ── Screen copy ───────────────────────────────────────────────────────────
  group('Step3Bio — copy and layout', () {
    testWidgets('shows correct title and subtitle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Tell people about yourself'), findsOneWidget);
      expect(find.text('One short line is enough.'), findsOneWidget);
    });

    testWidgets('shows Skip button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byKey(const Key('skipButton')), findsOneWidget);
    });

    testWidgets('shows "Start swapping" on the primary button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Start swapping'), findsOneWidget);
    });
  });
}
