import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/screens/chats/match_list_screen.dart';

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
  );
}

Widget _buildScreen({
  required Stream<List<MatchRowData>> stream,
  void Function(String matchId)? onChatTap,
}) {
  return MaterialApp(
    home: MatchListScreen(
      getCurrentUid: () => 'user1',
      matchesStream: stream,
      onChatTap: onChatTap,
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
