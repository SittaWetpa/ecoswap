/// Widget tests for QrScanScreen — WBS 10.4.
///
/// Coverage (per WBS 10.4 Testing section):
///   1. Permission denied → shows settings link.
///   2. Valid scan → calls validateQRToken (calls onComplete on success).
///   3. Each error code maps to the correct toast text.
///
/// All tests use injectable seams ([scannerBuilder], [tokenValidator],
/// [permissionDenied], [openSettingsCallback]) so no Firebase SDK or real
/// camera hardware is touched.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/screens/qr/qr_scan_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a MaterialApp with an initial home route containing a
/// push-trigger button. The QrScanScreen is pushed with [matchId] as the
/// route argument so [didChangeDependencies] can read it correctly.
Widget _wrap(Widget child, {String matchId = 'match-42'}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              settings: RouteSettings(arguments: matchId),
              builder: (_) => child,
            ),
          ),
          child: const Text('Open Scan'),
        ),
      ),
    ),
  );
}

/// Pushes the QrScanScreen onto the navigator by tapping the trigger button,
/// then pumps enough frames for the page transition to complete.
///
/// We deliberately avoid [pumpAndSettle] because the [_ScanLine] widget
/// runs a continuous repeating animation that never settles. Instead we
/// drive the clock forward by 500 ms (well beyond the 250 ms page-push
/// animation) and then pump one more frame to flush any pending microtasks.
Future<void> _openScreen(WidgetTester tester) async {
  await tester.tap(find.text('Open Scan'));
  await tester.pump(); // start the route push
  await tester.pump(const Duration(milliseconds: 500)); // complete transition
  await tester.pump(); // flush microtasks (e.g. Future<void> in initState)
}

// ---------------------------------------------------------------------------
// Fake scanner builder — calls onDetect immediately with a supplied token
// ---------------------------------------------------------------------------

/// Returns a [ScannerBuilder] that renders a tappable button. When tapped,
/// it calls [onDetect] with [token], simulating a successful QR detection.
ScannerBuilder _fakeScannerBuilder(String token) {
  return (onDetect) => Builder(
    builder: (context) => TextButton(
      onPressed: () => onDetect(token),
      child: const Text('Simulate scan'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('QrScanScreen', () {
    // ── Test 1: permission denied → shows settings link ────────────────────
    //
    // When [permissionDenied] is true, the screen skips the camera view and
    // renders the _PermissionDeniedPlaceholder, which contains an
    // "Open settings" link.

    testWidgets('permission denied shows settings link', (tester) async {
      var settingsTapped = false;

      await tester.pumpWidget(
        _wrap(
          QrScanScreen(
            permissionDenied: true,
            openSettingsCallback: () => settingsTapped = true,
          ),
        ),
      );

      await _openScreen(tester);

      // The permission explanation text must be visible.
      expect(find.text('Camera access needed'), findsOneWidget);
      expect(
        find.textContaining('EcoSwap needs camera access'),
        findsOneWidget,
      );

      // The "Open settings" link must be present.
      expect(find.text('Open settings'), findsOneWidget);

      // Tapping the link invokes the callback.
      await tester.tap(find.text('Open settings'));
      await tester.pump();
      expect(settingsTapped, isTrue);
    });

    // ── Test 2: valid scan → calls validateQRToken (onComplete fires) ───────
    //
    // When the injected scanner fires with a token and the injected validator
    // returns a success map, the screen should call [onComplete] with the
    // tradeId from the result.

    testWidgets('valid scan calls validateQRToken and fires onComplete', (
      tester,
    ) async {
      const fakeToken = 'header.payload.signature';
      const fakeTradeId = 'trade-abc123';

      String? capturedMatchId;
      String? capturedToken;
      String? receivedTradeId;

      Future<Map<String, dynamic>> fakeValidator(
        String matchId,
        String token,
      ) async {
        capturedMatchId = matchId;
        capturedToken = token;
        return {'success': true, 'tradeId': fakeTradeId};
      }

      await tester.pumpWidget(
        _wrap(
          QrScanScreen(
            scannerBuilder: _fakeScannerBuilder(fakeToken),
            tokenValidator: fakeValidator,
            onComplete: (tradeId) => receivedTradeId = tradeId,
          ),
          matchId: 'match-42',
        ),
      );

      await _openScreen(tester);

      // Tap the simulated scan button.
      await tester.tap(find.text('Simulate scan'));
      // Drive the clock forward to let the async validator complete.
      // Do NOT use pumpAndSettle — the _ScanLine animation loops forever.
      await tester.pump(); // start async call
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // let future resolve

      // Validator was called with the correct matchId and token.
      expect(capturedMatchId, 'match-42');
      expect(capturedToken, fakeToken);

      // onComplete received the tradeId from the validator result.
      expect(receivedTradeId, fakeTradeId);
    });

    // ── Test 3: error codes → correct toast text ───────────────────────────
    //
    // Each typed error code defined in WBS 10.2 must produce the exact
    // user-facing message specified in WBS 10.4 Deliverables.

    const errorCases = <String, String>{
      'INVALID_SIGNATURE': 'QR not recognised, try again',
      'EXPIRED': 'QR expired, ask them to refresh',
      'WRONG_COUNTERPARTY': "You can't scan your own QR",
      'ALREADY_USED': 'This swap is already complete',
      'MATCH_INVALID': 'This match is no longer active',
    };

    for (final entry in errorCases.entries) {
      final code = entry.key;
      final expectedMessage = entry.value;

      testWidgets('error code $code shows correct toast: "$expectedMessage"', (
        tester,
      ) async {
        const fakeToken = 'bad.token';

        Future<Map<String, dynamic>> failingValidator(
          String matchId,
          String token,
        ) async {
          throw FirebaseFunctionsException(
            message: code,
            code: code.toLowerCase(),
          );
        }

        await tester.pumpWidget(
          _wrap(
            QrScanScreen(
              scannerBuilder: _fakeScannerBuilder(fakeToken),
              tokenValidator: failingValidator,
              // onComplete must not be called on error.
              onComplete: (tradeId) {
                fail('onComplete should not be called on error');
              },
            ),
          ),
        );

        await _openScreen(tester);

        // Tap the simulated scan to trigger the validate path.
        await tester.tap(find.text('Simulate scan'));
        // Drive the clock forward to let the async validator throw and
        // the SnackBar to appear. Avoid pumpAndSettle — the _ScanLine
        // animation loops forever.
        await tester.pump(); // start async call
        await tester.pump(const Duration(milliseconds: 100)); // resolve future
        await tester.pump(const Duration(milliseconds: 100)); // show SnackBar

        // The SnackBar with the mapped message should appear.
        expect(
          find.text(expectedMessage),
          findsOneWidget,
          reason: 'Expected toast "$expectedMessage" for error code "$code"',
        );
      });
    }

    // ── Additional test: unknown error → generic fallback toast ────────────
    //
    // A non-typed exception (e.g., network error) should produce the generic
    // fallback message instead of leaking internal error details.

    testWidgets('unknown exception shows generic fallback toast', (
      tester,
    ) async {
      const fakeToken = 'some.token';

      Future<Map<String, dynamic>> crashingValidator(
        String matchId,
        String token,
      ) async {
        throw Exception('network timeout');
      }

      await tester.pumpWidget(
        _wrap(
          QrScanScreen(
            scannerBuilder: _fakeScannerBuilder(fakeToken),
            tokenValidator: crashingValidator,
          ),
        ),
      );

      await _openScreen(tester);

      await tester.tap(find.text('Simulate scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Something went wrong, please try again'),
        findsOneWidget,
      );
    });

    // ── Test: scanning is gated (no duplicate validate calls) ──────────────
    //
    // Tapping the scan button twice in rapid succession should only call
    // the validator once (_isValidating gate).

    testWidgets('rapid duplicate scans call validator only once', (
      tester,
    ) async {
      const fakeToken = 'tok';
      var callCount = 0;
      final completer = Completer<Map<String, dynamic>>();

      Future<Map<String, dynamic>> slowValidator(String matchId, String token) {
        callCount++;
        return completer.future;
      }

      await tester.pumpWidget(
        _wrap(
          QrScanScreen(
            scannerBuilder: _fakeScannerBuilder(fakeToken),
            tokenValidator: slowValidator,
            onComplete: (_) {},
          ),
        ),
      );

      await _openScreen(tester);

      // First tap — starts the validate call.
      await tester.tap(find.text('Simulate scan'));
      await tester.pump(); // process setState(_isValidating = true)

      // Second tap — should be a no-op because _isValidating is true.
      await tester.tap(find.text('Simulate scan'));
      await tester.pump();

      expect(callCount, 1, reason: 'Validator should only be called once');

      // Resolve the pending future so the test can clean up.
      completer.complete({'success': true, 'tradeId': 'trade-x'});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
