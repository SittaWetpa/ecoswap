/// Widget + persistence tests for the How-It-Works tutorial carousel.
///
/// Covers:
///   1. Renders the first slide; "Next" advances through to "Get started".
///   2. "Get started" on the last slide invokes onDone.
///   3. First-run mode shows "Skip" (which invokes onDone); replay mode shows
///      a close (X) instead, and no "Skip".
///   4. hasSeenTutorial() / markTutorialSeen() persistence round-trip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/screens/tutorial/tutorial_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('TutorialScreen', () {
    testWidgets('renders the first slide and advances with "Next"', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(TutorialScreen(onDone: () {})));

      // First slide.
      expect(find.text('Discover & swipe'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);

      // Advance to the second slide.
      await tester.tap(find.byKey(const Key('tutorialNext')));
      await tester.pumpAndSettle();
      expect(find.text('Match & chat'), findsOneWidget);
    });

    testWidgets('last slide shows "Get started" which invokes onDone', (
      tester,
    ) async {
      var done = false;
      await tester.pumpWidget(_wrap(TutorialScreen(onDone: () => done = true)));

      // Tap Next until the final slide (4 slides → 3 advances).
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('tutorialNext')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Track your impact'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutorialNext')));
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('first-run shows Skip (invokes onDone); no close X', (
      tester,
    ) async {
      var done = false;
      await tester.pumpWidget(
        _wrap(TutorialScreen(onDone: () => done = true, showSkip: true)),
      );

      expect(find.byKey(const Key('tutorialSkip')), findsOneWidget);
      expect(find.byKey(const Key('tutorialClose')), findsNothing);

      await tester.tap(find.byKey(const Key('tutorialSkip')));
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('replay mode shows a close X and no Skip', (tester) async {
      var done = false;
      await tester.pumpWidget(
        _wrap(TutorialScreen(onDone: () => done = true, showSkip: false)),
      );

      expect(find.byKey(const Key('tutorialSkip')), findsNothing);
      expect(find.byKey(const Key('tutorialClose')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutorialClose')));
      await tester.pump();
      expect(done, isTrue);
    });
  });

  group('tutorial persistence', () {
    testWidgets('hasSeenTutorial is false until markTutorialSeen is called', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      expect(await hasSeenTutorial(), isFalse);

      await markTutorialSeen();
      expect(await hasSeenTutorial(), isTrue);
    });
  });
}
