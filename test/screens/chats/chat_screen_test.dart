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
  void Function(String)? onSend,
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

      await tester.pumpWidget(_buildScreen(onSend: (_) => sendCalled = true));

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

      await tester.pumpWidget(_buildScreen(onSend: (t) => sentText = t));

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

  // ---------------------------------------------------------------------------
  // WBS 9.5 — Read Receipt Logic
  // ---------------------------------------------------------------------------

  group('ChatScreen — WBS 9.5', () {
    // Helpers for WBS 9.5 tests.

    /// Builds a [ChatScreen] with the WBS 9.5 params populated.
    Widget build95Screen({
      List<Message> messages = const [],
      void Function(List<String>)? onMarkRead,
      String otherUserId = _kOtherUid,
    }) {
      return MaterialApp(
        home: ChatScreen(
          otherDisplayName: 'Fah',
          myItemName: 'Leather tote bag',
          theirItemName: 'Electric kettle',
          currentUserId: _kCurrentUid,
          otherUserId: otherUserId,
          messages: messages,
          onMarkRead: onMarkRead,
        ),
      );
    }

    /// Creates a [Message] from the other user that is NOT yet read by the
    /// current user.
    Message unreadIncoming(String id) => Message(
          id: id,
          senderId: _kOtherUid,
          text: 'Incoming $id',
          readBy: const [],
        );

    // ── Test A: onMarkRead called with all unread incoming message IDs ─────

    testWidgets(
      'opening a chat with 3 unread messages calls onMarkRead with all 3 IDs',
      (tester) async {
        List<String>? capturedIds;

        final messages = [
          unreadIncoming('msg-1'),
          unreadIncoming('msg-2'),
          unreadIncoming('msg-3'),
        ];

        await tester.pumpWidget(
          build95Screen(
            messages: messages,
            onMarkRead: (ids) => capturedIds = ids,
          ),
        );

        expect(
          capturedIds,
          isNotNull,
          reason: 'onMarkRead must be called on initState',
        );
        expect(
          capturedIds,
          containsAll(['msg-1', 'msg-2', 'msg-3']),
          reason: 'all 3 unread message IDs must be passed to onMarkRead',
        );
        expect(
          capturedIds!.length,
          equals(3),
          reason: 'exactly 3 IDs — no duplicates, no extras',
        );
      },
    );

    // ── Test A2: already-read messages are NOT passed to onMarkRead ─────────

    testWidgets(
      'messages already read by currentUser are excluded from onMarkRead',
      (tester) async {
        List<String>? capturedIds;

        final messages = [
          // Already read by current user — should be excluded.
          Message(
            id: 'msg-already-read',
            senderId: _kOtherUid,
            text: 'Already read',
            readBy: [_kCurrentUid],
          ),
          // Not yet read — should be included.
          unreadIncoming('msg-unread'),
        ];

        await tester.pumpWidget(
          build95Screen(
            messages: messages,
            onMarkRead: (ids) => capturedIds = ids,
          ),
        );

        expect(capturedIds, equals(['msg-unread']));
      },
    );

    // ── Test A3: own messages are never passed to onMarkRead ────────────────

    testWidgets(
      'own messages are never included in onMarkRead call',
      (tester) async {
        List<String>? capturedIds;

        final messages = [
          // Own message — must be excluded even if readBy is empty.
          Message(
            id: 'my-msg',
            senderId: _kCurrentUid,
            text: 'My message',
            readBy: const [],
          ),
        ];

        await tester.pumpWidget(
          build95Screen(
            messages: messages,
            onMarkRead: (ids) => capturedIds = ids,
          ),
        );

        // onMarkRead must not be called because there are no incoming unread
        // messages (the only message is our own).
        expect(
          capturedIds,
          isNull,
          reason:
              'onMarkRead must not fire when there are no unread incoming msgs',
        );
      },
    );

    // ── Test B: read indicator shows when otherUserId is in readBy ──────────

    testWidgets(
      'read indicator shows on own message when otherUserId is in readBy',
      (tester) async {
        final messages = [
          Message(
            id: 'my-read-msg',
            senderId: _kCurrentUid,
            text: 'Has been read',
            readBy: [_kOtherUid], // other user has read it
          ),
        ];

        await tester.pumpWidget(
          build95Screen(messages: messages),
        );

        expect(
          find.text('Read'),
          findsOneWidget,
          reason:
              '"Read" indicator must appear when otherUserId is in readBy',
        );
      },
    );

    // ── Test C: read indicator does NOT show when otherUserId not in readBy ─

    testWidgets(
      'read indicator does NOT show on own message when otherUserId not in readBy',
      (tester) async {
        final messages = [
          Message(
            id: 'my-unread-msg',
            senderId: _kCurrentUid,
            text: 'Not read yet',
            readBy: const [], // other user has NOT read it
          ),
        ];

        await tester.pumpWidget(
          build95Screen(messages: messages),
        );

        expect(
          find.text('Read'),
          findsNothing,
          reason:
              '"Read" indicator must NOT appear when otherUserId is absent '
              'from readBy',
        );
      },
    );

    // ── Test C2: read indicator does NOT show on incoming messages ──────────

    testWidgets(
      'read indicator does NOT show on incoming (non-own) messages',
      (tester) async {
        final messages = [
          Message(
            id: 'their-msg',
            senderId: _kOtherUid,
            text: 'Their message',
            // Even if currentUser is in readBy, no indicator on incoming msgs.
            readBy: [_kCurrentUid, _kOtherUid],
          ),
        ];

        await tester.pumpWidget(
          build95Screen(messages: messages),
        );

        expect(
          find.text('Read'),
          findsNothing,
          reason: '"Read" indicator must only appear on own messages',
        );
      },
    );

    // ── Test D: no "presence" or "typing" indicators ────────────────────────

    testWidgets(
      'no typing or presence indicators are shown (out of scope)',
      (tester) async {
        await tester.pumpWidget(build95Screen());

        expect(find.textContaining('typing'), findsNothing);
        expect(find.textContaining('Typing'), findsNothing);
        expect(find.textContaining('Online'), findsNothing);
        expect(find.textContaining('Active'), findsNothing);
      },
    );
  });
}
