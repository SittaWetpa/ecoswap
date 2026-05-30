/// Widget tests for the MainShell ↔ match-celebration wiring (WBS 8.4).
///
/// Regression coverage for the bug where the match-detection backend created
/// a `/matches/` doc but the celebration screen never appeared, because the
/// [MatchListener] was never wired into the running app.
///
/// A controllable proposal stream is injected via
/// [MainShell.matchProposalStreamOverride] so the test drives the overlay
/// without touching Firebase.
library;

import 'dart:async';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/match/match_celebration_screen.dart';
import 'package:ecoswap/screens/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Item _makeItem({String id = 'item-1', String name = 'Electric kettle'}) {
  return Item(
    id: id,
    ownerId: 'owner',
    name: name,
    category: ItemCategory.kitchenware,
    condition: ItemCondition.likeNew,
    photoUrl: '',
    status: ItemStatus.active,
  );
}

User _makeUser({String uid = 'user-other', String displayName = 'Fah'}) {
  const emptyDistrict = HomeDistrict(
    provinceId: '',
    provinceNameTh: '',
    provinceNameEn: '',
    districtId: '',
    districtNameTh: '',
    districtNameEn: '',
  );
  return User(
    uid: uid,
    email: 'fah@example.com',
    displayName: displayName,
    photoUrl: '',
    homeDistrict: emptyDistrict,
    bio: '',
  );
}

MatchProposal _makeProposal({String matchId = 'match-1'}) {
  return MatchProposal(
    matchId: matchId,
    otherUser: _makeUser(displayName: 'Fah'),
    myItem: _makeItem(id: 'item-my', name: 'Electric kettle'),
    theirItem: _makeItem(id: 'item-their', name: 'Desk lamp'),
  );
}

const _stubTabs = <int, Widget>{
  0: Scaffold(body: Center(child: Text('Stub Discover'))),
  1: Scaffold(body: Center(child: Text('Stub Chats'))),
  2: Scaffold(body: Center(child: Text('Stub Impact'))),
  3: Scaffold(body: Center(child: Text('Stub Profile'))),
};

void main() {
  group('MainShell — match celebration wiring', () {
    testWidgets('a proposal from the stream surfaces the celebration screen', (
      tester,
    ) async {
      final controller = StreamController<MatchProposal>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            tabOverrides: _stubTabs,
            matchProposalStreamOverride: controller.stream,
          ),
        ),
      );
      await tester.pump();

      // No celebration before any proposal arrives.
      expect(find.byType(MatchCelebrationScreen), findsNothing);

      controller.add(_makeProposal());
      await tester.pumpAndSettle();

      // The celebration overlay is now on screen.
      expect(find.byType(MatchCelebrationScreen), findsOneWidget);
      expect(find.text("It's a match!"), findsOneWidget);
    });

    testWidgets('"Keep swiping" dismisses the celebration', (tester) async {
      final controller = StreamController<MatchProposal>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            tabOverrides: _stubTabs,
            matchProposalStreamOverride: controller.stream,
          ),
        ),
      );
      await tester.pump();

      controller.add(_makeProposal());
      await tester.pumpAndSettle();
      expect(find.byType(MatchCelebrationScreen), findsOneWidget);

      await tester.ensureVisible(find.text('Keep swiping'));
      await tester.tap(find.text('Keep swiping'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchCelebrationScreen), findsNothing);
    });

    testWidgets('"Send a message" dismisses and switches to the Chats tab', (
      tester,
    ) async {
      final controller = StreamController<MatchProposal>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            tabOverrides: _stubTabs,
            matchProposalStreamOverride: controller.stream,
          ),
        ),
      );
      await tester.pump();

      // Starts on Discover.
      expect(find.text('Stub Discover'), findsOneWidget);

      controller.add(_makeProposal());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Send a message'));
      await tester.tap(find.text('Send a message'));
      await tester.pumpAndSettle();

      // Celebration gone; the Chats tab is now active.
      expect(find.byType(MatchCelebrationScreen), findsNothing);
      expect(find.text('Stub Chats'), findsOneWidget);
    });
  });
}
