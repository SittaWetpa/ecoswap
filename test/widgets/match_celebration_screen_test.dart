/// Widget tests for WBS 8.4 — Match Celebration Screen
///
/// Covers every testing requirement listed in the WBS 8.4 entry:
///   1. A new match doc surfaces the celebration screen
///   2. Re-foregrounding with same match does not re-show
///   3. Tapping "Send a message" navigates to chat
library;

import 'dart:async';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/match.dart' as match_model;
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/match/match_celebration_screen.dart';
import 'package:ecoswap/services/match_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Minimal active [Item] for testing.
Item _makeItem({
  String id = 'item-1',
  String name = 'Electric kettle',
  ItemCategory category = ItemCategory.kitchenware,
}) {
  return Item(
    id: id,
    ownerId: 'owner',
    name: name,
    category: category,
    condition: ItemCondition.likeNew,
    photoUrl: '',
    status: ItemStatus.active,
  );
}

/// Minimal [User] for testing.
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

/// A [MatchProposal] with known values for assertions.
MatchProposal _makeProposal({
  String matchId = 'match-1',
  String otherUserName = 'Fah',
  String myItemName = 'Electric kettle',
  String theirItemName = 'Desk lamp',
}) {
  return MatchProposal(
    matchId: matchId,
    otherUser: _makeUser(displayName: otherUserName),
    myItem: _makeItem(id: 'item-my', name: myItemName),
    theirItem: _makeItem(
      id: 'item-their',
      name: theirItemName,
      category: ItemCategory.household,
    ),
  );
}

/// A minimal [match_model.Match] with the given matchId.
match_model.Match _makeMatch({String id = 'match-1'}) {
  return match_model.Match(
    id: id,
    userAId: 'uid-me',
    userBId: 'user-other',
    userAWantsItemId: 'item-their',
    userBWantsItemId: 'item-my',
    status: match_model.MatchStatus.active,
    participants: ['uid-me', 'user-other'],
  );
}

// ---------------------------------------------------------------------------
// Fake doc fetcher for tests
// ---------------------------------------------------------------------------

/// Returns injected fake Firestore data.  The maps mirror the Firestore
/// document format so [Item.fromJson] and [User.fromJson] can parse them.
Map<String, dynamic> Function(String, String) _fakeFetcher({
  required Item myItem,
  required Item theirItem,
  required User otherUser,
}) {
  final itemsStore = {
    myItem.id: {
      'ownerId': myItem.ownerId,
      'name': myItem.name,
      'category': myItem.category.value,
      'condition': myItem.condition.value,
      'photoUrl': myItem.photoUrl,
      'status': myItem.status.value,
    },
    theirItem.id: {
      'ownerId': theirItem.ownerId,
      'name': theirItem.name,
      'category': theirItem.category.value,
      'condition': theirItem.condition.value,
      'photoUrl': theirItem.photoUrl,
      'status': theirItem.status.value,
    },
  };
  final usersStore = {
    otherUser.uid: {
      'email': otherUser.email,
      'displayName': otherUser.displayName,
      'photoUrl': otherUser.photoUrl,
      'homeDistrict': otherUser.homeDistrict.toJson(),
      'bio': otherUser.bio,
      'tradesCount': 0,
      'totalCo2Saved': 0.0,
      'totalWasteDiverted': 0.0,
    },
  };
  return (String collection, String docId) {
    if (collection == 'items') return itemsStore[docId] ?? {};
    if (collection == 'users') return usersStore[docId] ?? {};
    return {};
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. A new match doc surfaces the celebration screen
  // -------------------------------------------------------------------------

  group('MatchCelebrationScreen — surfacing', () {
    testWidgets('new match proposal shows the celebration screen', (
      tester,
    ) async {
      final proposal = _makeProposal(
        otherUserName: 'Fah',
        myItemName: 'Electric kettle',
        theirItemName: 'Desk lamp',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MatchCelebrationScreen(
            proposal: proposal,
            onSendMessage: (_) {},
            onKeepSwiping: () {},
          ),
        ),
      );

      // Screen shows "It's a match!" headline copy.
      expect(find.textContaining("It's a match!"), findsOneWidget);
      // Shows the other user's name.
      expect(find.textContaining('Fah'), findsWidgets);
      // Shows my item name.
      expect(find.text('Electric kettle'), findsOneWidget);
      // Shows their item name.
      expect(find.text('Desk lamp'), findsOneWidget);
      // Shows the two column labels.
      expect(find.text('YOU GIVE'), findsOneWidget);
      expect(find.text('YOU GET'), findsOneWidget);
    });

    test('MatchListener emits a proposal when a new match arrives', () async {
      final matchesController = StreamController<List<match_model.Match>>();
      final seenIds = <String>{};
      final match = _makeMatch(id: 'match-abc');
      final myItem = _makeItem(id: 'item-my', name: 'Electric kettle');
      final theirItem = _makeItem(
        id: 'item-their',
        name: 'Desk lamp',
        category: ItemCategory.household,
      );
      final otherUser = _makeUser(uid: 'user-other', displayName: 'Fah');

      final fetcher = _fakeFetcher(
        myItem: myItem,
        theirItem: theirItem,
        otherUser: otherUser,
      );

      final listener = MatchListener(
        currentUserId: 'uid-me',
        matchesStreamFactory: (_) => matchesController.stream,
        seenLoader: () async => seenIds,
        seenMarker: (id) async => seenIds.add(id),
        docFetcher: (col, id) async => fetcher(col, id),
      );
      listener.start();

      // Collect the first proposal emitted.
      final proposalFuture = listener.proposals.first;

      // Emit a new match.
      matchesController.add([match]);

      // Await the proposal directly — no widget pumping needed for a unit test.
      final proposal = await proposalFuture;

      expect(proposal.matchId, equals('match-abc'));
      expect(proposal.myItem.name, equals('Electric kettle'));
      expect(proposal.theirItem.name, equals('Desk lamp'));
      expect(proposal.otherUser.displayName, equals('Fah'));
      // Match is now in seenIds.
      expect(seenIds, contains('match-abc'));

      listener.dispose();
      await matchesController.close();
    });
  });

  // -------------------------------------------------------------------------
  // 2. Re-foregrounding with same match does not re-show
  //    These are pure unit tests of MatchListener (no widget pumping needed).
  // -------------------------------------------------------------------------

  group('MatchCelebrationScreen — one-time display', () {
    test('already-seen matchId is not emitted by MatchListener', () async {
      final matchesController = StreamController<List<match_model.Match>>();

      // Pre-populate seen set with the match that will arrive.
      final seenIds = <String>{'match-already-seen'};

      final myItem = _makeItem(id: 'item-my', name: 'Electric kettle');
      final theirItem = _makeItem(
        id: 'item-their',
        name: 'Desk lamp',
        category: ItemCategory.household,
      );
      final otherUser = _makeUser(uid: 'user-other');
      final fetcher = _fakeFetcher(
        myItem: myItem,
        theirItem: theirItem,
        otherUser: otherUser,
      );

      final emitted = <MatchProposal>[];

      final listener = MatchListener(
        currentUserId: 'uid-me',
        matchesStreamFactory: (_) => matchesController.stream,
        seenLoader: () async => seenIds,
        seenMarker: (id) async => seenIds.add(id),
        docFetcher: (col, id) async => fetcher(col, id),
      );
      listener.start();
      final sub = listener.proposals.listen(emitted.add);

      // Emit the already-seen match and allow the async chain to drain.
      matchesController.add([_makeMatch(id: 'match-already-seen')]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // No proposal should have been emitted.
      expect(emitted, isEmpty);

      sub.cancel();
      listener.dispose();
      await matchesController.close();
    });

    test('same matchId not emitted twice by MatchListener', () async {
      final matchesController = StreamController<List<match_model.Match>>();
      final seenIds = <String>{};
      final match = _makeMatch(id: 'match-once');
      final myItem = _makeItem(id: 'item-my', name: 'Electric kettle');
      final theirItem = _makeItem(
        id: 'item-their',
        name: 'Desk lamp',
        category: ItemCategory.household,
      );
      final otherUser = _makeUser(uid: 'user-other');
      final fetcher = _fakeFetcher(
        myItem: myItem,
        theirItem: theirItem,
        otherUser: otherUser,
      );

      final emitted = <MatchProposal>[];

      final listener = MatchListener(
        currentUserId: 'uid-me',
        matchesStreamFactory: (_) => matchesController.stream,
        seenLoader: () async => seenIds,
        seenMarker: (id) async => seenIds.add(id),
        docFetcher: (col, id) async => fetcher(col, id),
      );
      listener.start();
      final sub = listener.proposals.listen(emitted.add);

      // First emission — one proposal should arrive.
      matchesController.add([match]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emitted, hasLength(1));
      expect(seenIds, contains('match-once'));

      // Second emission of the same match — no new proposal.
      matchesController.add([match]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emitted, hasLength(1)); // still only 1

      sub.cancel();
      listener.dispose();
      await matchesController.close();
    });
  });

  // -------------------------------------------------------------------------
  // 3. Tapping "Send a message" navigates to chat
  // -------------------------------------------------------------------------

  group('MatchCelebrationScreen — Send a message CTA', () {
    testWidgets('tapping "Send a message" calls onSendMessage with matchId', (
      tester,
    ) async {
      // Use a tall surface so the full screen fits without scrolling.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? receivedMatchId;
      const testMatchId = 'match-xyz';
      final proposal = _makeProposal(matchId: testMatchId);

      await tester.pumpWidget(
        MaterialApp(
          home: MatchCelebrationScreen(
            proposal: proposal,
            onSendMessage: (id) => receivedMatchId = id,
            onKeepSwiping: () {},
          ),
        ),
      );

      await tester.tap(find.text('Send a message'));
      await tester.pump();

      expect(
        receivedMatchId,
        equals(testMatchId),
        reason: 'onSendMessage must be called with the correct matchId',
      );
    });

    testWidgets('tapping "Keep swiping" calls onKeepSwiping', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool calledKeep = false;
      final proposal = _makeProposal();

      await tester.pumpWidget(
        MaterialApp(
          home: MatchCelebrationScreen(
            proposal: proposal,
            onSendMessage: (_) {},
            onKeepSwiping: () => calledKeep = true,
          ),
        ),
      );

      await tester.tap(find.text('Keep swiping'));
      await tester.pump();

      expect(calledKeep, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // CO₂ estimate banner
  // -------------------------------------------------------------------------

  group('MatchCelebrationScreen — CO₂ banner', () {
    testWidgets('CO₂ estimate banner is visible', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final proposal = _makeProposal();

      await tester.pumpWidget(
        MaterialApp(
          home: MatchCelebrationScreen(
            proposal: proposal,
            onSendMessage: (_) {},
            onKeepSwiping: () {},
          ),
        ),
      );

      // The CO₂ banner uses RichText (not Text), so use byWidgetPredicate.
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('CO₂'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Complete this swap'),
        ),
        findsOneWidget,
      );
    });
  });
}
