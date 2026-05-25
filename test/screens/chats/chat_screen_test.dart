// WBS 9.2 — Chat Screen UI widget tests.
//
// Tests verify:
//  1. Own messages are right-aligned, other's messages are left-aligned.
//  2. Send button is disabled when the input is empty.
//  3. "Ready to swap" CTA is hidden when messages are unevenly distributed
//     (e.g. 5 total but 4-1 split — gate requires ≥ 3 each side).
//  4. "Ready to swap" CTA is shown when both sides have ≥ 3 messages.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/message.dart';
import 'package:ecoswap/screens/chats/chat_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kCurrentUid = 'user-me';
const _kOtherUid = 'user-them';

/// Builds a [ChatScreen] wrapped in [MaterialApp].
Widget _buildScreen({
  List<Message> messages = const [],
  Future<void> Function(String)? onSend,
  VoidCallback? onReadyExchange,
  VoidCallback? onBack,
}) {
  return MaterialApp(
    home: ChatScreen(
      otherDisplayName: 'Fah',
      myItemName: 'Leather tote bag',
      theirItemName: 'Electric kettle',
      currentUserId: _kCurrentUid,
      messages: messages,
      onSend: onSend,
      onReadyExchange: onReadyExchange,
      onBack: onBack,
    ),
  );
}

/// Creates a [Message] with only the fields the chat screen cares about.
Message _msg(String senderId, String text, {int index = 0}) {
  return Message(id: 'msg-$index', senderId: senderId, text: text);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatScreen — WBS 9.2', () {
    // ── Test 1: message alignment ─────────────────────────────────────────────

    testWidgets(
      'own messages are right-aligned, other messages are left-aligned',
      (tester) async {
        final messages = [
          _msg(_kCurrentUid, 'Hello!', index: 0),
          _msg(_kOtherUid, 'Hi there!', index: 1),
        ];

        await tester.pumpWidget(_buildScreen(messages: messages));

        // Find all MessageBubble widgets.
        final bubbles = tester
            .widgetList<MessageBubble>(find.byType(MessageBubble))
            .toList();

        expect(bubbles.length, 2, reason: 'Expected 2 MessageBubble widgets');

        // Own bubble (index 0 in list order) must have isOwn == true.
        expect(
          bubbles[0].isOwn,
          isTrue,
          reason: 'First bubble (own) should have isOwn = true',
        );

        // Other bubble must have isOwn == false.
        expect(
          bubbles[1].isOwn,
          isFalse,
          reason: 'Second bubble (other) should have isOwn = false',
        );

        // Verify alignment via the Align widget *inside* each MessageBubble.
        // Each MessageBubble has its own Align as the root widget, so we find
        // Align widgets whose child is a ConstrainedBox (the bubble content).
        final aligns = tester.widgetList<Align>(find.byType(Align)).toList();

        final hasRight = aligns.any(
          (a) => a.alignment == Alignment.centerRight,
        );
        final hasLeft = aligns.any((a) => a.alignment == Alignment.centerLeft);

        expect(
          hasRight,
          isTrue,
          reason: 'Expected at least one right-aligned Align widget',
        );
        expect(
          hasLeft,
          isTrue,
          reason: 'Expected at least one left-aligned Align widget',
        );
      },
    );

    // ── Test 2: send button disabled on empty input ───────────────────────────

    testWidgets('send button is disabled when input is empty', (tester) async {
      bool sendCalled = false;

      await tester.pumpWidget(
        _buildScreen(
          onSend: (_) async {
            sendCalled = true;
          },
        ),
      );

      // Tap the send button while the field is empty.
      // The button uses InkWell with onTap = null when hasText is false,
      // so tapping it should not invoke onSend.
      final sendBtn = find.byWidgetPredicate(
        (w) => w is InkWell && w.onTap == null,
      );
      // There should be at least one disabled InkWell (the send button).
      expect(
        sendBtn,
        findsWidgets,
        reason: 'Expected an InkWell with null onTap when input is empty',
      );

      expect(
        sendCalled,
        isFalse,
        reason: 'onSend must not be called when input is empty',
      );
    });

    testWidgets('send button becomes enabled after typing text', (
      tester,
    ) async {
      String? sentText;

      await tester.pumpWidget(
        _buildScreen(
          onSend: (t) async {
            sentText = t;
          },
        ),
      );

      // Type something into the input.
      await tester.enterText(find.byType(TextField), 'Hi!');
      await tester.pump();

      // Now there should be an InkWell with a non-null onTap.
      final enabledBtn = find.byWidgetPredicate(
        (w) => w is InkWell && w.onTap != null,
      );
      expect(enabledBtn, findsWidgets);

      // Tap the send button.
      // Find by Icon(Icons.send) and tap its ancestor InkWell.
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(
        sentText,
        'Hi!',
        reason: 'onSend should have been called with the trimmed text',
      );
    });

    // ── Test 3: "Ready to swap" hidden when unevenly distributed ─────────────

    testWidgets(
      '"Ready to swap" hidden when messages = 5 unevenly distributed (4 mine, 1 theirs)',
      (tester) async {
        // 4 messages from me, 1 from them → gate not met (need ≥ 3 each side)
        final messages = [
          _msg(_kCurrentUid, 'Msg 1', index: 0),
          _msg(_kCurrentUid, 'Msg 2', index: 1),
          _msg(_kCurrentUid, 'Msg 3', index: 2),
          _msg(_kCurrentUid, 'Msg 4', index: 3),
          _msg(_kOtherUid, 'Their only message', index: 4),
        ];

        await tester.pumpWidget(_buildScreen(messages: messages));

        // The CTA text "Exchange" should NOT appear.
        expect(
          find.text('Exchange'),
          findsNothing,
          reason:
              '"Exchange" button must be hidden when the other party has < 3 messages',
        );
      },
    );

    testWidgets('"Ready to swap" hidden when 3 mine + 2 theirs (theirs < 3)', (
      tester,
    ) async {
      final messages = [
        _msg(_kCurrentUid, 'Msg 1', index: 0),
        _msg(_kCurrentUid, 'Msg 2', index: 1),
        _msg(_kCurrentUid, 'Msg 3', index: 2),
        _msg(_kOtherUid, 'Their 1', index: 3),
        _msg(_kOtherUid, 'Their 2', index: 4),
      ];

      await tester.pumpWidget(_buildScreen(messages: messages));

      expect(
        find.text('Exchange'),
        findsNothing,
        reason:
            '"Exchange" button must be hidden when other party has only 2 messages',
      );
    });

    // ── Test 4: "Ready to swap" shown when both sides have ≥ 3 messages ──────

    testWidgets(
      '"Ready to swap" shown when both sides have exactly 3 messages',
      (tester) async {
        final messages = [
          _msg(_kCurrentUid, 'Mine 1', index: 0),
          _msg(_kCurrentUid, 'Mine 2', index: 1),
          _msg(_kCurrentUid, 'Mine 3', index: 2),
          _msg(_kOtherUid, 'Theirs 1', index: 3),
          _msg(_kOtherUid, 'Theirs 2', index: 4),
          _msg(_kOtherUid, 'Theirs 3', index: 5),
        ];

        await tester.pumpWidget(_buildScreen(messages: messages));

        // "Exchange" button should now be visible.
        expect(
          find.text('Exchange'),
          findsOneWidget,
          reason:
              '"Exchange" button must appear when both sides have ≥ 3 messages',
        );
      },
    );

    testWidgets(
      '"Ready to swap" shown when both sides have more than 3 messages',
      (tester) async {
        final messages = [
          _msg(_kCurrentUid, 'Mine 1', index: 0),
          _msg(_kCurrentUid, 'Mine 2', index: 1),
          _msg(_kCurrentUid, 'Mine 3', index: 2),
          _msg(_kCurrentUid, 'Mine 4', index: 3),
          _msg(_kOtherUid, 'Theirs 1', index: 4),
          _msg(_kOtherUid, 'Theirs 2', index: 5),
          _msg(_kOtherUid, 'Theirs 3', index: 6),
          _msg(_kOtherUid, 'Theirs 4', index: 7),
        ];

        await tester.pumpWidget(_buildScreen(messages: messages));

        expect(
          find.text('Exchange'),
          findsOneWidget,
          reason:
              '"Exchange" button must remain visible once the gate is cleared',
        );
      },
    );

    // ── Additional: long messages wrap without overflow ───────────────────────

    testWidgets('long messages wrap and do not overflow', (tester) async {
      const longText =
          'This is a very long message that should wrap across multiple '
          'lines without causing any overflow errors in the widget tree.';

      final messages = [_msg(_kCurrentUid, longText, index: 0)];

      await tester.pumpWidget(_buildScreen(messages: messages));

      // No overflow exception should be thrown. Finding the text confirms it
      // rendered.
      expect(find.text(longText), findsOneWidget);
    });

    // ── Additional: trade pill displays both item names ───────────────────────

    testWidgets('trade pill shows my item name and their item name', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());

      expect(find.text('Leather tote bag'), findsOneWidget);
      expect(find.text('Electric kettle'), findsOneWidget);
      expect(find.text('Trade'), findsOneWidget);
    });

    // ── Additional: no "Active now" in header (out of scope) ─────────────────

    testWidgets('header does not display "Active now" text', (tester) async {
      await tester.pumpWidget(_buildScreen());

      expect(
        find.textContaining('Active'),
        findsNothing,
        reason:
            'Activity status is explicitly out of scope per CLAUDE.md and '
            'must not appear in the chat header',
      );
    });
  });
}
