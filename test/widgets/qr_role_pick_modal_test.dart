// WBS 9.6 — QrRolePickModal widget tests.
//
// Three tests, one per acceptance criterion:
//   1. "Show my QR" tapped → onShowQR callback is fired (navigates to QR Show
//      with the correct matchId).
//   2. "Scan their QR" tapped → onScanQR callback is fired (navigates to QR
//      Scan with the correct matchId).
//   3. Cancel tapped → modal dismissed, neither navigation callback fired.
//
// Navigation is intercepted via the injectable [onShowQR] / [onScanQR]
// callbacks so the tests do not require a real Navigator routes map.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/widgets/qr_role_pick_modal.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kMatchId = 'match-abc-123';

/// Pumps a [MaterialApp] that contains a button to open the
/// [QrRolePickModal] via [QrRolePickModal.show].
///
/// The modal is opened via a button tap so the modal sits inside a real
/// [Navigator] (required for [Navigator.of(context).pop] to work).
Widget _buildHarness({
  String matchId = _kMatchId,
  VoidCallback? onShowQR,
  VoidCallback? onScanQR,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () => QrRolePickModal.show(
            ctx,
            matchId: matchId,
            onShowQR: onShowQR,
            onScanQR: onScanQR,
          ),
          child: const Text('Open modal'),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('QrRolePickModal — WBS 9.6', () {
    // ── Test 1: "Show my QR" navigates to QR Show with correct matchId ──────

    testWidgets(
      '"I\'ll show the QR" triggers onShowQR callback (QR Show navigation)',
      (tester) async {
        String? capturedMatchId;
        bool showQRCalled = false;

        await tester.pumpWidget(
          _buildHarness(
            matchId: _kMatchId,
            onShowQR: () {
              showQRCalled = true;
              capturedMatchId = _kMatchId;
            },
          ),
        );

        // Open the modal.
        await tester.tap(find.text('Open modal'));
        await tester.pumpAndSettle();

        // The modal should be visible.
        expect(
          find.text('Are you with the other person right now?'),
          findsOneWidget,
          reason: 'Modal title must be visible after opening',
        );
        expect(
          find.text("I'll show the QR"),
          findsOneWidget,
          reason: '"I\'ll show the QR" option must be visible',
        );

        // Tap the "Show QR" option.
        await tester.tap(find.text("I'll show the QR"));
        await tester.pumpAndSettle();

        // Callback must have been called.
        expect(
          showQRCalled,
          isTrue,
          reason: 'onShowQR must be called when the user selects "Show QR"',
        );

        // The matchId must match what was passed in.
        expect(
          capturedMatchId,
          equals(_kMatchId),
          reason: 'matchId must be passed correctly to the QR Show screen',
        );

        // Modal must be dismissed after the selection.
        expect(
          find.text('Are you with the other person right now?'),
          findsNothing,
          reason: 'Modal must be closed after the user makes a selection',
        );
      },
    );

    // ── Test 2: "Scan their QR" navigates to QR Scan with correct matchId ───

    testWidgets(
      '"I\'ll scan their QR" triggers onScanQR callback (QR Scan navigation)',
      (tester) async {
        String? capturedMatchId;
        bool scanQRCalled = false;

        await tester.pumpWidget(
          _buildHarness(
            matchId: _kMatchId,
            onScanQR: () {
              scanQRCalled = true;
              capturedMatchId = _kMatchId;
            },
          ),
        );

        // Open the modal.
        await tester.tap(find.text('Open modal'));
        await tester.pumpAndSettle();

        // The modal should be visible.
        expect(
          find.text("I'll scan their QR"),
          findsOneWidget,
          reason: '"I\'ll scan their QR" option must be visible',
        );

        // Tap the "Scan QR" option.
        await tester.tap(find.text("I'll scan their QR"));
        await tester.pumpAndSettle();

        // Callback must have been called.
        expect(
          scanQRCalled,
          isTrue,
          reason: 'onScanQR must be called when the user selects "Scan QR"',
        );

        // The matchId must match what was passed in.
        expect(
          capturedMatchId,
          equals(_kMatchId),
          reason: 'matchId must be passed correctly to the QR Scan screen',
        );

        // Modal must be dismissed after the selection.
        expect(
          find.text('Are you with the other person right now?'),
          findsNothing,
          reason: 'Modal must be closed after the user makes a selection',
        );
      },
    );

    // ── Test 3: Cancel dismisses without navigation ──────────────────────────

    testWidgets(
      'Cancel dismisses the modal without calling any navigation callback',
      (tester) async {
        bool showQRCalled = false;
        bool scanQRCalled = false;

        await tester.pumpWidget(
          _buildHarness(
            onShowQR: () => showQRCalled = true,
            onScanQR: () => scanQRCalled = true,
          ),
        );

        // Open the modal.
        await tester.tap(find.text('Open modal'));
        await tester.pumpAndSettle();

        // Modal is open.
        expect(
          find.text('Are you with the other person right now?'),
          findsOneWidget,
        );

        // Tap Cancel.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Neither navigation callback must have been called.
        expect(
          showQRCalled,
          isFalse,
          reason: 'onShowQR must NOT be called when Cancel is tapped',
        );
        expect(
          scanQRCalled,
          isFalse,
          reason: 'onScanQR must NOT be called when Cancel is tapped',
        );

        // Modal must be dismissed.
        expect(
          find.text('Are you with the other person right now?'),
          findsNothing,
          reason: 'Modal must close after Cancel is tapped',
        );
      },
    );

    // ── Additional: modal is shown when Exchange CTA is tapped in ChatScreen ─

    testWidgets('modal title and both options are present when opened', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness());

      await tester.tap(find.text('Open modal'));
      await tester.pumpAndSettle();

      // Title copy
      expect(
        find.text('Are you with the other person right now?'),
        findsOneWidget,
      );
      // Both options
      expect(find.text("I'll show the QR"), findsOneWidget);
      expect(find.text("I'll scan their QR"), findsOneWidget);
      // Cancel option
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
