import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/message.dart';
import 'package:ecoswap/screens/chats/chat_screen.dart';
import 'package:ecoswap/screens/chats/match_list_screen.dart';
import 'package:ecoswap/services/chat_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MatchRowData _fakeRow({
  String matchId = 'match-1',
  String otherUserName = 'Fah',
  String otherUserPhotoUrl = '',
  String myItemName = 'Electric Kettle',
  String theirItemName = 'Leather Tote',
  String lastMessage = 'See you there',
  DateTime? lastMessageTime,
  int unreadCount = 0,
  String currentUserId = 'user1',
  String otherUserId = 'user2',
  bool isCompleted = false,
}) {
  return MatchRowData(
    matchId: matchId,
    otherUserName: otherUserName,
    otherUserPhotoUrl: otherUserPhotoUrl,
    myItemName: myItemName,
    theirItemName: theirItemName,
    lastMessage: lastMessage,
    lastMessageTime: lastMessageTime,
    unreadCount: unreadCount,
    currentUserId: currentUserId,
    otherUserId: otherUserId,
    isCompleted: isCompleted,
  );
}

/// A Firebase-free [ChatService] for the production-tap test: an empty
/// message stream and no-op writers, so opening [ChatScreen] never touches
/// Firestore.
ChatService _fakeChatService() => ChatService(
  streamFactory: (_) => Stream<List<Message>>.value(const []),
  currentUserId: 'user1',
  messageDocAdder: (_, _) async => 'msg-1',
  batchCommitter: (_) async {},
);

Widget _buildScreen({
  required Stream<List<MatchRowData>> stream,
  void Function(String matchId)? onChatTap,
  ChatService Function()? chatServiceFactory,
}) {
  return MaterialApp(
    home: MatchListScreen(
      getCurrentUid: () => 'user1',
      matchesStream: stream,
      onChatTap: onChatTap,
      chatServiceFactory: chatServiceFactory,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — WBS 9.1
// ---------------------------------------------------------------------------

void main() {
  group('MatchListScreen', () {
    // ── Test 1: 2 active + 1 cancelled → 2 rows visible ──────────────────────
    //
    // The Firestore query excludes cancelled matches, so the stream only emits
    // the two non-cancelled rows. Verify both user names are shown.

    testWidgets('user with 2 active + 1 cancelled match sees 2 rows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = StreamController<List<MatchRowData>>();

      await tester.pumpWidget(_buildScreen(stream: controller.stream));

      // Stream emits only the 2 non-cancelled rows (cancelled was filtered
      // by the Firestore query before reaching the screen).
      controller.add([
        _fakeRow(matchId: 'm1', otherUserName: 'Fah'),
        _fakeRow(matchId: 'm2', otherUserName: 'Ploy'),
      ]);
      await tester.pump();

      expect(find.text('Fah'), findsOneWidget);
      expect(find.text('Ploy'), findsOneWidget);

      await controller.close();
    });

    // ── Test 1b: completed match shows the "Swapped" chip (decision #4) ──────
    //
    // A completed match stays in the list (the chat is the trade record) but
    // is flagged with a "Swapped" chip; an active match shows none.

    testWidgets('completed match row shows a "Swapped" chip; active does not', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = StreamController<List<MatchRowData>>();
      await tester.pumpWidget(_buildScreen(stream: controller.stream));

      controller.add([
        _fakeRow(matchId: 'm1', otherUserName: 'Fah', isCompleted: true),
        _fakeRow(matchId: 'm2', otherUserName: 'Ploy'),
      ]);
      await tester.pump();

      // Both rows present; exactly one carries the Swapped chip.
      expect(find.text('Fah'), findsOneWidget);
      expect(find.text('Ploy'), findsOneWidget);
      expect(find.text('Swapped'), findsOneWidget);

      await controller.close();
    });

    // ── Test 2: trade pill shows "Your X ⇄ their Y" ───────────────────────────

    testWidgets('trade pill correctly shows "Your X ⇄ their Y"', (
      tester,
    ) async {
      final controller = StreamController<List<MatchRowData>>();

      await tester.pumpWidget(_buildScreen(stream: controller.stream));

      controller.add([
        _fakeRow(
          matchId: 'm1',
          myItemName: 'Electric Kettle',
          theirItemName: 'Leather Tote',
        ),
      ]);
      await tester.pump();

      // Trade pill uses first word of each item name.
      expect(find.text('Your Electric ⇄ their Leather'), findsOneWidget);

      await controller.close();
    });

    // ── Test 3: tap on row calls onChatTap with the correct matchId ───────────

    testWidgets('tap on row navigates to correct chat', (tester) async {
      final controller = StreamController<List<MatchRowData>>();
      String? tappedMatchId;

      await tester.pumpWidget(
        _buildScreen(
          stream: controller.stream,
          onChatTap: (id) => tappedMatchId = id,
        ),
      );

      controller.add([_fakeRow(matchId: 'match-456', otherUserName: 'Beam')]);
      await tester.pump();

      await tester.tap(find.text('Beam'));
      await tester.pump();

      expect(tappedMatchId, equals('match-456'));

      await controller.close();
    });

    // ── Test 3b: production tap opens ChatScreen (no missing-route crash) ──────
    //
    // Regression: with no onChatTap injected, the row used to push the
    // unregistered '/chat' named route, throwing "Could not find a generator
    // for route". The default path now pushes ChatScreen directly.

    testWidgets('production tap (no onChatTap) opens ChatScreen', (
      tester,
    ) async {
      final controller = StreamController<List<MatchRowData>>();

      await tester.pumpWidget(
        _buildScreen(
          stream: controller.stream,
          chatServiceFactory: _fakeChatService,
        ),
      );

      controller.add([
        _fakeRow(
          matchId: 'm-prod',
          otherUserName: 'Beam',
          myItemName: 'Electric Kettle',
          theirItemName: 'Leather Tote',
        ),
      ]);
      await tester.pump();

      await tester.tap(find.text('Beam'));
      await tester.pumpAndSettle();

      // No "Could not find a generator for route" exception was thrown...
      expect(tester.takeException(), isNull);
      // ...and ChatScreen is now on screen.
      expect(find.byType(ChatScreen), findsOneWidget);

      await controller.close();
    });

    // ── Test 4: empty state when user has 0 matches ───────────────────────────

    testWidgets('empty state shown when user has 0 matches', (tester) async {
      final controller = StreamController<List<MatchRowData>>();

      await tester.pumpWidget(_buildScreen(stream: controller.stream));

      controller.add([]);
      await tester.pump();

      expect(find.text('No matches yet'), findsOneWidget);
      expect(
        find.text(
          'Start swiping on the Discover tab to find people to swap with.',
        ),
        findsOneWidget,
      );
      expect(find.text('Go to Discover'), findsOneWidget);

      await controller.close();
    });
  });
}
