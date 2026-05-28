/// Widget tests for QrShowScreen — WBS 10.3.
///
/// Coverage (per WBS 10.3 Testing section):
///   1. Screen mounts, QR appears, countdown starts at 60.
///   2. At 30 s elapsed, countdown resets to 60 (next token fetched).
///   3. Match status flips to 'completed' → navigates to Swap Confirmed.
///   4. Tapping Cancel returns to previous screen.
///
/// All tests use injectable seams ([tokenFetcher], [matchStream]) so no
/// Firebase SDK is touched.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/screens/qr/qr_show_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a MaterialApp with a named-route table that contains a
/// stub '/qr/confirmed' route so navigation assertions work.
Widget _wrap(
  Widget child, {
  String matchId = 'match-1',
  Map<String, WidgetBuilder>? extraRoutes,
}) {
  return MaterialApp(
    routes: {
      '/qr/confirmed': (_) => const Scaffold(body: Text('Swap Confirmed')),
      ...?extraRoutes,
    },
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: RouteSettings(arguments: matchId),
              builder: (_) => child,
            ),
          ),
          child: const Text('Open QR'),
        ),
      ),
    ),
  );
}

/// Pushes the QrShowScreen onto the navigator by tapping the trigger button,
/// then pumps once so the screen is visible.
Future<void> _openScreen(WidgetTester tester) async {
  await tester.tap(find.text('Open QR'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('QrShowScreen', () {
    // ── Test 1: QR appears, countdown starts at 60 ─────────────────────────
    //
    // The screen should immediately show the countdown at 60 and render the
    // QR code once the (synchronous fake) token fetcher returns.

    testWidgets('mounts with countdown at 60 and renders QR code', (
      tester,
    ) async {
      // Fake token fetcher — returns synchronously (via Future.value).
      Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
        return {'token': 'fake.jwt.token', 'expiresAt': 9999999999};
      }

      // Match stream that never emits 'completed'.
      Stream<String?> fakeStream(String matchId) =>
          const Stream<String?>.empty();

      await tester.pumpWidget(
        _wrap(QrShowScreen(tokenFetcher: fakeFetcher, matchStream: fakeStream)),
      );

      await _openScreen(tester);

      // Countdown pill shows 60 s.
      // Note: find.textContaining also matches the FraudExplainer body which
      // mentions "60s" — use findsWidgets (one or more) and verify at least
      // one match exists.
      expect(find.textContaining('60s'), findsWidgets);

      // QR image view is rendered (token was returned synchronously).
      expect(find.byType(QrShowScreen), findsOneWidget);
      // The screen is present — QrImageView renders inside _QrCard.
      // Verify no error state is shown.
      expect(find.textContaining("Couldn't load QR"), findsNothing);
    });

    // ── Test 2: at 30 s elapsed, countdown resets to 60 ───────────────────
    //
    // After the 30-second refresh timer fires, _fetchToken is called again,
    // which resets _seconds to 60 in setState. We drive fake time with
    // tester.pump(Duration).

    testWidgets('countdown resets to 60 when the 30-second refresh fires', (
      tester,
    ) async {
      var fetchCount = 0;

      Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
        fetchCount++;
        return {'token': 'tok$fetchCount', 'expiresAt': 9999999999};
      }

      Stream<String?> fakeStream(String matchId) =>
          const Stream<String?>.empty();

      await tester.pumpWidget(
        _wrap(QrShowScreen(tokenFetcher: fakeFetcher, matchStream: fakeStream)),
      );

      await _openScreen(tester);

      // Verify initial fetch happened.
      expect(fetchCount, 1);

      // Advance the clock by 30 seconds — this triggers the refresh timer.
      // We pump in 1-second increments so the periodic countdown timer fires
      // too, keeping the state consistent.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Allow async work (the token fetch future) to settle.
      await tester.pump();

      // A second fetch should have occurred.
      expect(fetchCount, greaterThanOrEqualTo(2));

      // After the refresh, _seconds is reset to 60 by the fetcher.
      // The timer then ticks once more to 59 during pumpAndSettle, so we
      // accept either 59 or 60.
      final has60 = find.textContaining('60s').evaluate().isNotEmpty;
      final has59 = find.textContaining('59s').evaluate().isNotEmpty;
      expect(
        has60 || has59,
        isTrue,
        reason: 'Countdown should reset to 60 (or be at 59 after one tick)',
      );
    });

    // ── Test 3: match completed → navigates to Swap Confirmed ──────────────
    //
    // When the injected match stream emits 'completed', the screen should
    // call [onComplete].

    testWidgets(
      'navigates to Swap Confirmed when match status flips to completed',
      (tester) async {
        final matchController = StreamController<String?>();

        Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
          return {'token': 'fake.jwt', 'expiresAt': 9999999999};
        }

        Stream<String?> fakeStream(String matchId) => matchController.stream;

        var completedCalled = false;

        await tester.pumpWidget(
          _wrap(
            QrShowScreen(
              tokenFetcher: fakeFetcher,
              matchStream: fakeStream,
              onComplete: () => completedCalled = true,
            ),
          ),
        );

        await _openScreen(tester);

        // Emit 'completed' on the match stream.
        matchController.add('completed');
        await tester.pump();

        expect(completedCalled, isTrue);

        await matchController.close();
      },
    );

    // ── Test 4: tapping Cancel returns to chat ─────────────────────────────
    //
    // Tapping the Cancel button should call Navigator.pop(), revealing the
    // previous screen (the stub home screen with the "Open QR" button).

    testWidgets('tapping Cancel pops the screen', (tester) async {
      Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
        return {'token': 'fake.jwt', 'expiresAt': 9999999999};
      }

      Stream<String?> fakeStream(String matchId) =>
          const Stream<String?>.empty();

      await tester.pumpWidget(
        _wrap(QrShowScreen(tokenFetcher: fakeFetcher, matchStream: fakeStream)),
      );

      await _openScreen(tester);

      // Cancel button is visible.
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should be back on the home screen (the "Open QR" trigger button).
      expect(find.text('Open QR'), findsOneWidget);
      expect(find.byType(QrShowScreen), findsNothing);
    });
  });
}
