/// Widget tests for WBS 9.4 — Optimistic UI (sendMessage)
///
/// Verifies that:
///   - A message appears immediately in the UI before the Firestore
///     round-trip completes (the optimistic "sending" state).
///   - The "sending" clock icon is shown while the write is in-flight.
///   - The "sent" checkmark is shown once the write completes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/message.dart';
import 'package:ecoswap/screens/chats/chat_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kCurrentUid = 'user-me';

/// Builds a [ChatScreen] that delegates [onSend] to [sendHandler].
Widget _buildScreen({
  List<Message> messages = const [],
  required Future<void> Function(String) sendHandler,
}) {
  return MaterialApp(
    home: ChatScreen(
      otherDisplayName: 'Fah',
      myItemName: 'Leather tote bag',
      theirItemName: 'Electric kettle',
      currentUserId: _kCurrentUid,
      messages: messages,
      onSend: sendHandler,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatScreen optimistic UI — WBS 9.4', () {
    // ── Test 4: message appears before Firestore round-trip completes ─────────

    testWidgets(
      'optimistic UI shows message immediately before onSend Future resolves',
      (tester) async {
        // A Completer lets us hold the send Future open so we can inspect the
        // UI while the write is still "in-flight".
        final completer = Completer<void>();

        await tester.pumpWidget(
          _buildScreen(sendHandler: (_) => completer.future),
        );

        // Type a message and tap Send.
        await tester.enterText(find.byType(TextField), 'Hello optimistic!');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));

        // pump() once — this lets the state update run but does NOT advance
        // timers or await Futures, so the completer is still open.
        await tester.pump();

        // The message text must already be visible (optimistic UI).
        expect(
          find.text('Hello optimistic!'),
          findsOneWidget,
          reason: 'Message must appear immediately, before the write completes',
        );

        // The "sending" clock icon must be visible while in-flight.
        expect(
          find.byIcon(Icons.access_time),
          findsOneWidget,
          reason:
              'Clock icon must be shown while the Firestore write is in-flight',
        );

        // Now resolve the Future (simulating Firestore ack).
        completer.complete();
        await tester.pump();

        // The checkmark must replace the clock.
        expect(
          find.byIcon(Icons.check),
          findsOneWidget,
          reason: 'Check icon must appear once the write completes',
        );
        expect(
          find.byIcon(Icons.access_time),
          findsNothing,
          reason: 'Clock icon must be gone after write completes',
        );

        // The message text must still be visible.
        expect(find.text('Hello optimistic!'), findsOneWidget);
      },
    );

    testWidgets('input field is cleared immediately after tapping Send', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        _buildScreen(sendHandler: (_) => completer.future),
      );

      await tester.enterText(find.byType(TextField), 'Clear me');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Input field should be empty immediately.
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(
        tf.controller?.text ?? '',
        isEmpty,
        reason: 'Input must be cleared as soon as Send is tapped',
      );

      completer.complete();
      await tester.pump();
    });

    // ── Test: optimistic message is not duplicated once the stream reflects it ─
    //
    // Regression: the optimistic bubble used to linger after the real Firestore
    // message arrived via the stream, so a single send showed twice.

    testWidgets(
      'optimistic message is reconciled (not duplicated) when stream echoes it',
      (tester) async {
        final controller = StreamController<List<Message>>();

        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(
              otherDisplayName: 'Fah',
              myItemName: 'Tote bag',
              theirItemName: 'Electric kettle',
              currentUserId: _kCurrentUid,
              messageStream: controller.stream,
              onSend: (_) async {},
            ),
          ),
        );

        // Send a message → optimistic bubble appears immediately.
        await tester.enterText(find.byType(TextField), 'Round trip');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();
        expect(find.text('Round trip'), findsOneWidget);

        // The stream now echoes the same message back from Firestore (as the
        // current user). The optimistic copy must be dropped — exactly one
        // bubble, not two.
        controller.add([
          Message(id: 'srv-1', senderId: _kCurrentUid, text: 'Round trip'),
        ]);
        await tester.pump();

        expect(
          find.text('Round trip'),
          findsOneWidget,
          reason: 'The message must render once, not duplicated',
        );

        await controller.close();
      },
    );

    testWidgets('optimistic message is removed on send error', (tester) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        _buildScreen(sendHandler: (_) => completer.future),
      );

      await tester.enterText(find.byType(TextField), 'Will fail');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Optimistic message visible while in-flight.
      expect(find.text('Will fail'), findsOneWidget);

      // Simulate Firestore error.
      completer.completeError(Exception('network error'));
      await tester.pump();

      // Optimistic message should be removed.
      expect(
        find.text('Will fail'),
        findsNothing,
        reason: 'Optimistic message must be removed on send error',
      );
    });
  });
}
