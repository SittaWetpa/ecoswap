// WBS 9.3 — Firestore Real-Time Listener tests.
//
// Tests specified in the WBS entry:
//   1. Widget test: stream emits new message → message appears in UI.
//   2. Widget test: navigating away cancels the subscription.
//
// Additional tests:
//   3. Unit test: ChatService.messageStream() returns a stream (smoke test,
//      uses injected factory — no Firebase required).
//   4. Widget test: initial static messages displayed before stream emits.
//   5. Widget test: stream emitting 50 messages shows all 50 (cap check).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/message.dart';
import 'package:ecoswap/screens/chats/chat_screen.dart';
import 'package:ecoswap/services/chat_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kCurrentUid = 'user-me';
const _kOtherUid = 'user-them';

Message _msg(String senderId, String text, {String id = 'msg-1'}) {
  return Message(id: id, senderId: senderId, text: text);
}

/// Builds [ChatScreen] with an injected [messageStream].
Widget _buildWithStream({
  required Stream<List<Message>> messageStream,
  List<Message> initialMessages = const [],
  VoidCallback? onBack,
}) {
  return MaterialApp(
    home: ChatScreen(
      otherDisplayName: 'Fah',
      myItemName: 'Tote bag',
      theirItemName: 'Electric kettle',
      currentUserId: _kCurrentUid,
      messages: initialMessages,
      messageStream: messageStream,
      onBack: onBack,
    ),
  );
}

/// Builds [ChatScreen] with an injected [ChatService] (uses matchId path).
Widget _buildWithService({
  required ChatService chatService,
  VoidCallback? onBack,
}) {
  return MaterialApp(
    home: ChatScreen(
      otherDisplayName: 'Fah',
      myItemName: 'Tote bag',
      theirItemName: 'Electric kettle',
      currentUserId: _kCurrentUid,
      matchId: 'match-abc',
      chatService: chatService,
      onBack: onBack,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatService — WBS 9.3', () {
    // ── Test 3: smoke test messageStream() with injected factory ─────────────

    test('messageStream() returns a stream from the injected factory', () {
      final controller = StreamController<List<Message>>();
      final service = ChatService(streamFactory: (_) => controller.stream);

      final stream = service.messageStream('match-123');

      // The returned stream should be the same object the factory produced.
      expect(stream, isA<Stream<List<Message>>>());

      controller.close();
    });

    test('messageStream() calls factory with the provided matchId', () {
      String? capturedMatchId;
      final controller = StreamController<List<Message>>();
      final service = ChatService(
        streamFactory: (id) {
          capturedMatchId = id;
          return controller.stream;
        },
      );

      service.messageStream('match-xyz');

      expect(capturedMatchId, equals('match-xyz'));

      controller.close();
    });
  });

  group('ChatScreen real-time listener — WBS 9.3', () {
    // ── Test 1: stream emits new message → message appears in UI ─────────────

    testWidgets('stream emits a new message and it appears in the UI', (
      tester,
    ) async {
      final controller = StreamController<List<Message>>();

      await tester.pumpWidget(
        _buildWithStream(messageStream: controller.stream),
      );

      // No messages yet.
      expect(find.byType(MessageBubble), findsNothing);

      // Stream emits one message from the other party.
      controller.add([_msg(_kOtherUid, 'Hello from Fah!')]);
      await tester.pump();

      expect(find.text('Hello from Fah!'), findsOneWidget);
      expect(find.byType(MessageBubble), findsOneWidget);

      await controller.close();
    });

    testWidgets('stream emitting multiple messages shows all of them', (
      tester,
    ) async {
      final controller = StreamController<List<Message>>();

      await tester.pumpWidget(
        _buildWithStream(messageStream: controller.stream),
      );

      controller.add([
        _msg(_kCurrentUid, 'Hi!', id: 'msg-1'),
        _msg(_kOtherUid, 'Hey!', id: 'msg-2'),
        _msg(_kCurrentUid, 'How are you?', id: 'msg-3'),
      ]);
      await tester.pump();

      expect(find.byType(MessageBubble), findsNWidgets(3));
      expect(find.text('Hi!'), findsOneWidget);
      expect(find.text('Hey!'), findsOneWidget);
      expect(find.text('How are you?'), findsOneWidget);

      await controller.close();
    });

    // ── Test 2: navigating away cancels the subscription ─────────────────────
    //
    // Strategy: directly dispose the ChatScreen's state via replaceWidget,
    // bypassing route animations entirely. This is the most reliable way to
    // verify dispose() cancels the subscription without fighting fake-time.

    testWidgets(
      'navigating away from ChatScreen cancels the stream subscription',
      (tester) async {
        bool listenerCancelled = false;

        // sync broadcast controller: onCancel fires synchronously when
        // cancel() is called, which is compatible with Flutter's fake-async
        // test environment (no real-time waits needed).
        final trackingController = StreamController<List<Message>>.broadcast(
          sync: true,
          onCancel: () => listenerCancelled = true,
        );

        // Mount the ChatScreen directly (no Navigator push needed).
        await tester.pumpWidget(
          MaterialApp(
            home: ChatScreen(
              otherDisplayName: 'Fah',
              myItemName: 'Tote bag',
              theirItemName: 'Electric kettle',
              currentUserId: _kCurrentUid,
              messageStream: trackingController.stream,
            ),
          ),
        );

        expect(find.byType(ChatScreen), findsOneWidget);
        expect(listenerCancelled, isFalse);

        // Replace the widget tree with something else → ChatScreen is unmounted
        // → dispose() is called → _messageSubscription.cancel() is called
        // → onCancel fires synchronously (sync controller).
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Text('Other screen'))),
        );

        // dispose() has been called; onCancel fired synchronously.
        expect(
          listenerCancelled,
          isTrue,
          reason:
              'StreamSubscription must be cancelled in ChatScreen.dispose() '
              'to prevent memory leaks (WBS 9.3)',
        );

        await trackingController.close();
      },
    );

    // ── Test 4: initial static messages shown before stream emits ────────────

    testWidgets(
      'static messages are shown before the stream emits its first batch',
      (tester) async {
        final controller = StreamController<List<Message>>();

        final initial = [_msg(_kCurrentUid, 'Pre-loaded message', id: 'pre-1')];

        await tester.pumpWidget(
          _buildWithStream(
            messageStream: controller.stream,
            initialMessages: initial,
          ),
        );

        // Stream has not emitted yet — static messages should be visible.
        expect(find.text('Pre-loaded message'), findsOneWidget);

        // Now stream emits and takes over.
        controller.add([_msg(_kOtherUid, 'Live message', id: 'live-1')]);
        await tester.pump();

        expect(find.text('Live message'), findsOneWidget);
        // Static message is replaced by the live batch.
        expect(find.text('Pre-loaded message'), findsNothing);

        await controller.close();
      },
    );

    // ── Test 5: stream capped at 50 messages renders newest-at-bottom ─────────
    //
    // Production streams messages ordered by sentAt DESCENDING (newest first),
    // and the list renders reversed so the newest sits at the bottom and is
    // visible without scrolling. Older messages are reachable by scrolling up.

    testWidgets(
      '50 messages from the stream: newest is at the bottom, oldest reachable',
      (tester) async {
        tester.view.physicalSize = const Size(400, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = StreamController<List<Message>>();

        await tester.pumpWidget(
          _buildWithStream(messageStream: controller.stream),
        );

        // Emit exactly 50 messages — the WBS 9.3 cap — newest first (the
        // production ordering). "Message 50" is the newest, "Message 1" oldest.
        final batch = List.generate(
          50,
          (i) => _msg(_kOtherUid, 'Message ${50 - i}', id: 'msg-$i'),
        );
        controller.add(batch);
        await tester.pump();

        expect(
          find.byType(MessageBubble),
          findsAtLeastNWidgets(1),
          reason: 'At least some of the 50 messages must be rendered',
        );
        // The newest message is anchored at the bottom and visible initially.
        expect(find.text('Message 50'), findsOneWidget);

        // Scroll up toward the older messages and verify the oldest is reachable.
        await tester.scrollUntilVisible(
          find.text('Message 1'),
          300.0,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Message 1'), findsOneWidget);

        await controller.close();
      },
    );

    // ── Test: chatService path — matchId + ChatService build the stream ───────

    testWidgets(
      'ChatScreen subscribes via ChatService when matchId is provided',
      (tester) async {
        final controller = StreamController<List<Message>>();
        final service = ChatService(streamFactory: (_) => controller.stream);

        await tester.pumpWidget(_buildWithService(chatService: service));

        controller.add([_msg(_kOtherUid, 'Via service stream')]);
        await tester.pump();

        expect(find.text('Via service stream'), findsOneWidget);

        await controller.close();
      },
    );
  });
}
