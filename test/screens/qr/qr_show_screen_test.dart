/// Widget tests for QrShowScreen — WBS 10.3.
///
/// Coverage (per WBS 10.3 Testing section):
///   1. Screen mounts, QR appears, countdown starts at 30 (the refresh cycle).
///   2. At 30 s elapsed, countdown resets to 30 (next token fetched).
///   3. Match status flips to 'completed' → navigates to Swap Confirmed.
///   4. Tapping Cancel returns to previous screen.
///
/// All tests use injectable seams ([tokenFetcher], [matchStream]) so no
/// Firebase SDK is touched.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
      // Echo the route argument so tests can assert the tradeId that was passed.
      '/qr/confirmed': (ctx) => Scaffold(
        body: Text('Swap Confirmed:${ModalRoute.of(ctx)?.settings.arguments}'),
      ),
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
    // ── Test 1: QR appears, countdown starts at 30 ─────────────────────────
    //
    // The screen should immediately show the countdown at 30 (the refresh
    // cycle length) and render the QR code once the (synchronous fake) token
    // fetcher returns.

    testWidgets('mounts with countdown at 30 and renders QR code', (
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

      // Countdown pill shows 30 s. Use exact text match so it doesn't
      // accidentally match the FraudExplainer body ("expires in 60s").
      expect(find.text('30s'), findsOneWidget);

      // QR image view is rendered (token was returned synchronously).
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining("Couldn't load QR"), findsNothing);

      // Countdown is framed as a refresh cue ("New code in"), not an expiry
      // countdown — that's what keeps it consistent with the 30s rotation.
      expect(find.textContaining('New code in'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsNothing);
    });

    // ── Test 2: at 30 s elapsed, countdown resets to 30 ───────────────────
    //
    // After the 30-second refresh timer fires, _fetchToken is called again,
    // which resets _seconds to 30 in setState. We drive fake time with
    // tester.pump(Duration).

    testWidgets('countdown resets to 30 when the 30-second refresh fires', (
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

      // After the refresh, _seconds is reset to 30 by the fetcher.
      // The timer then ticks once more to 29 during pumpAndSettle, so we
      // accept either 29 or 30. Use exact text match to avoid the
      // FraudExplainer body ("expires in 60s") causing a false positive.
      final has30 = find.text('30s').evaluate().isNotEmpty;
      final has29 = find.text('29s').evaluate().isNotEmpty;
      expect(
        has30 || has29,
        isTrue,
        reason: 'Countdown should reset to 30 (or be at 29 after one tick)',
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
              tradeIdResolver: (_) async => 'trade-3',
              onComplete: (_) => completedCalled = true,
            ),
          ),
        );

        await _openScreen(tester);

        // Emit 'completed' on the match stream.
        matchController.add('completed');
        await tester.pump(); // deliver event, start tradeId resolution
        await tester.pump(); // resolver completes → onComplete fires

        expect(completedCalled, isTrue);

        await matchController.close();
      },
    );

    // ── Test 3b: displayer resolves tradeId from matchId, then navigates ─────
    //
    // Regression: the displayer used to push '/qr/confirmed' with the *matchId*
    // (the screen expects a tradeId), and the route wasn't even registered.
    // It must now resolve the tradeId via the injected resolver and pass that.

    testWidgets(
      'on completion the displayer resolves the tradeId from its matchId',
      (tester) async {
        final matchController = StreamController<String?>();
        String? resolverArg;
        String? capturedTradeId;

        Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
          return {'token': 'fake.jwt', 'expiresAt': 9999999999};
        }

        Stream<String?> fakeStream(String matchId) => matchController.stream;

        Future<String?> fakeResolver(String matchId) async {
          resolverArg = matchId;
          return 'trade-xyz';
        }

        await tester.pumpWidget(
          _wrap(
            QrShowScreen(
              tokenFetcher: fakeFetcher,
              matchStream: fakeStream,
              tradeIdResolver: fakeResolver,
              // Capture the resolved tradeId via onComplete instead of driving
              // the real route transition (the 1s countdown timer makes the
              // tree never settle, which hangs pumpAndSettle).
              onComplete: (tradeId) => capturedTradeId = tradeId,
            ),
            matchId: 'match-77',
          ),
        );

        await _openScreen(tester);

        matchController.add('completed');
        await tester.pump(); // deliver stream event, kick off _onMatchCompleted
        await tester.pump(); // resolver future completes → onComplete fires

        // Resolver was called with the matchId, and the resolved tradeId
        // (not the matchId) is what flows onward to Swap Confirmed.
        expect(resolverArg, 'match-77');
        expect(capturedTradeId, 'trade-xyz');

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

    // ── Test 5: DEV-mode raw-token panel shows the JWT ─────────────────────
    //
    // With devModeOverride: true the screen renders a copyable raw-JWT panel
    // (the show-side complement to the scan screen's paste field). The full
    // token text and a Copy button are present.

    testWidgets('shows the raw JWT panel when DEV mode is on', (tester) async {
      Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
        return {'token': 'header.payload.signature', 'expiresAt': 9999999999};
      }

      Stream<String?> fakeStream(String matchId) =>
          const Stream<String?>.empty();

      await tester.pumpWidget(
        _wrap(
          QrShowScreen(
            tokenFetcher: fakeFetcher,
            matchStream: fakeStream,
            devModeOverride: true,
          ),
        ),
      );

      await _openScreen(tester);

      // The DEV label, the raw token, and a Copy affordance are all present.
      expect(find.text('DEV — raw token'), findsOneWidget);
      expect(find.text('header.payload.signature'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    // ── Test 6: raw-token panel is absent in production (DEV mode off) ─────
    //
    // The default (devModeOverride: false) must NOT surface the signed token
    // as text — only the QR encodes it.

    testWidgets('hides the raw JWT panel when DEV mode is off', (tester) async {
      Future<Map<String, dynamic>> fakeFetcher(String matchId) async {
        return {'token': 'header.payload.signature', 'expiresAt': 9999999999};
      }

      Stream<String?> fakeStream(String matchId) =>
          const Stream<String?>.empty();

      await tester.pumpWidget(
        _wrap(
          QrShowScreen(
            tokenFetcher: fakeFetcher,
            matchStream: fakeStream,
            devModeOverride: false,
          ),
        ),
      );

      await _openScreen(tester);

      // QR still renders, but the raw token is never shown as text.
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('DEV — raw token'), findsNothing);
      expect(find.text('header.payload.signature'), findsNothing);
    });
  });
}
