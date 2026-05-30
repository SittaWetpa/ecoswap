/// Widget tests for WBS 7.3 — Swipe Card UI
///
/// Covers every acceptance criterion listed in the entry:
///   1. Right-swipe gesture calls [onRightSwipe]
///   2. Left-swipe gesture calls [onLeftSwipe]
///   3. Tap (no horizontal movement) calls [onCardTap]
///   4. Card displays district as "Thai · English, Province"
///   5. Card displays no out-of-scope UI elements
///      (no "verified", no "active now", no age, no km)
library;

import 'package:ecoswap/models/incoming_interest.dart';
import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/discover/discover_screen.dart';
import 'package:ecoswap/widgets/proximity_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a minimal [User] for testing. No age, no trust score.
User _makeUser({
  String uid = 'user-1',
  String displayName = 'Ploy',
  String districtNameTh = 'บางมด',
  String districtNameEn = 'Bang Mod',
  String provinceNameEn = 'Bangkok',
  String provinceNameTh = 'กรุงเทพมหานคร',
  String provinceId = '10',
  String districtId = '1001',
  String photoUrl = '',
  String bio = 'Test bio',
}) {
  return User(
    uid: uid,
    email: '$uid@example.com',
    displayName: displayName,
    photoUrl: photoUrl,
    bio: bio,
    homeDistrict: HomeDistrict(
      provinceId: provinceId,
      provinceNameTh: provinceNameTh,
      provinceNameEn: provinceNameEn,
      districtId: districtId,
      districtNameTh: districtNameTh,
      districtNameEn: districtNameEn,
    ),
  );
}

/// Builds a minimal active [Item] for testing.
Item _makeItem({
  String id = 'item-1',
  String ownerId = 'user-1',
  String name = 'Leather tote bag',
  String photoUrl = '',
}) {
  return Item(
    id: id,
    ownerId: ownerId,
    name: name,
    category: ItemCategory.clothing,
    condition: ItemCondition.likeNew,
    photoUrl: photoUrl,
    status: ItemStatus.active,
  );
}

/// Wraps [child] in a minimal [MaterialApp] so widgets that use [Navigator]
/// or [MediaQuery] work in tests.
Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

/// Renders a [DiscoverScreen] with one candidate and returns the widget.
Widget _buildScreen({
  List<User>? candidates,
  Map<String, List<Item>>? itemsByUser,
  Map<String, IncomingInterest> interestMap = const {},
  ValueChanged<SwipeRecord>? onRightSwipe,
  ValueChanged<SwipeRecord>? onLeftSwipe,
  ValueChanged<User>? onCardTap,
  ValueChanged<ProximityBucket>? onProximityChanged,
  ProximityBucket bucket = ProximityBucket.sameProvince,
}) {
  final user = _makeUser();
  final item = _makeItem();
  return _wrap(
    DiscoverScreen(
      candidates: candidates ?? [user],
      itemsByUser:
          itemsByUser ??
          {
            user.uid: [item],
          },
      interestMap: interestMap,
      proximityBucket: bucket,
      onRightSwipe: onRightSwipe,
      onLeftSwipe: onLeftSwipe,
      onCardTap: onCardTap,
      onProximityChanged: onProximityChanged,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Right-swipe calls onRightSwipe
  // -------------------------------------------------------------------------

  group('DiscoverScreen — right-swipe', () {
    testWidgets(
      'right-swipe gesture calls onRightSwipe with the correct user',
      (tester) async {
        final records = <SwipeRecord>[];
        await tester.pumpWidget(_buildScreen(onRightSwipe: records.add));
        await tester.pumpAndSettle();

        // Simulate a right swipe: drag from centre past the 50px threshold.
        final cardFinder = find.byType(SwipeCard);
        expect(cardFinder, findsOneWidget);
        final center = tester.getCenter(cardFinder);

        await tester.dragFrom(center, const Offset(200, 0));
        await tester.pumpAndSettle();

        expect(records, hasLength(1));
        expect(records.first.user.uid, 'user-1');
        expect(records.first.direction, 'right');
      },
    );
  });

  // -------------------------------------------------------------------------
  // 2. Left-swipe calls onLeftSwipe
  // -------------------------------------------------------------------------

  group('DiscoverScreen — left-swipe', () {
    testWidgets('left-swipe gesture calls onLeftSwipe with the correct user', (
      tester,
    ) async {
      final records = <SwipeRecord>[];
      await tester.pumpWidget(_buildScreen(onLeftSwipe: records.add));
      await tester.pumpAndSettle();

      final cardFinder = find.byType(SwipeCard);
      expect(cardFinder, findsOneWidget);
      final center = tester.getCenter(cardFinder);

      await tester.dragFrom(center, const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(records, hasLength(1));
      expect(records.first.user.uid, 'user-1');
      // WBS 7.3 requirement: left-swipe must carry direction: 'left'
      // so the parent can write the Firestore doc with the correct field.
      expect(records.first.direction, 'left');
    });
  });

  // -------------------------------------------------------------------------
  // 3. Tap (no horizontal movement) calls onCardTap
  // -------------------------------------------------------------------------

  group('DiscoverScreen — tap on card', () {
    testWidgets('tap on card calls onCardTap with the correct user', (
      tester,
    ) async {
      final tapped = <User>[];
      await tester.pumpWidget(_buildScreen(onCardTap: tapped.add));
      await tester.pumpAndSettle();

      final cardFinder = find.byType(SwipeCard);
      expect(cardFinder, findsOneWidget);

      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(tapped, hasLength(1));
      expect(tapped.first.uid, 'user-1');
    });

    testWidgets('tap does not trigger onLeftSwipe or onRightSwipe', (
      tester,
    ) async {
      final rightSwiped = <SwipeRecord>[];
      final leftSwiped = <SwipeRecord>[];
      await tester.pumpWidget(
        _buildScreen(
          onRightSwipe: rightSwiped.add,
          onLeftSwipe: leftSwiped.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwipeCard));
      await tester.pumpAndSettle();

      expect(rightSwiped, isEmpty);
      expect(leftSwiped, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 4. District pill format: "Thai · English, Province"
  // -------------------------------------------------------------------------

  group('SwipeCard — district pill format', () {
    testWidgets(
      'district pill shows "districtTh · districtEn, provinceEn" format',
      (tester) async {
        final user = _makeUser(
          districtNameTh: 'บางมด',
          districtNameEn: 'Bang Mod',
          provinceNameEn: 'Bangkok',
        );
        await tester.pumpWidget(
          _wrap(
            DiscoverScreen(
              candidates: [user],
              itemsByUser: {
                user.uid: [_makeItem(ownerId: user.uid)],
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // District label appears in both the photo pill and the info section.
        expect(find.text('บางมด · Bang Mod, Bangkok'), findsAtLeast(1));
      },
    );

    testWidgets('district pill falls back gracefully when Thai name is empty', (
      tester,
    ) async {
      final user = _makeUser(
        districtNameTh: '',
        districtNameEn: 'Bang Mod',
        provinceNameEn: 'Bangkok',
      );
      await tester.pumpWidget(
        _wrap(
          DiscoverScreen(
            candidates: [user],
            itemsByUser: {
              user.uid: [_makeItem(ownerId: user.uid)],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bang Mod, Bangkok'), findsAtLeast(1));
    });

    testWidgets(
      'district pill shows "Th · En" without trailing comma when province empty',
      (tester) async {
        final user = _makeUser(
          districtNameTh: 'บางนา',
          districtNameEn: 'Bang Na',
          provinceNameEn: '',
        );
        await tester.pumpWidget(
          _wrap(
            DiscoverScreen(
              candidates: [user],
              itemsByUser: {
                user.uid: [_makeItem(ownerId: user.uid)],
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('บางนา · Bang Na'), findsAtLeast(1));
      },
    );
  });

  // -------------------------------------------------------------------------
  // 5. No out-of-scope UI elements
  // -------------------------------------------------------------------------

  group('SwipeCard — no out-of-scope UI elements', () {
    testWidgets('card does not show "verified" text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('verified', findRichText: true), findsNothing);
      expect(find.textContaining('Verified', findRichText: true), findsNothing);
    });

    testWidgets('card does not show activity status text', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('active now', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('active this', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('last seen', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('card does not show age or trust score', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining(' years', findRichText: true), findsNothing);
      expect(find.textContaining('yr old', findRichText: true), findsNothing);
      expect(find.textContaining('trust', findRichText: true), findsNothing);
    });

    testWidgets('card does not show km or distance', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining(' km', findRichText: true), findsNothing);
      expect(find.textContaining('away', findRichText: true), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Empty state shown when candidates list is empty
  // -------------------------------------------------------------------------

  group('DiscoverScreen — empty state', () {
    testWidgets('empty candidates list shows empty state, not a blank screen', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(candidates: [], itemsByUser: {}));
      await tester.pumpAndSettle();

      expect(find.text('No one nearby yet'), findsOneWidget);
      expect(find.byType(SwipeCard), findsNothing);
    });

    testWidgets('non-empty candidates list does not show empty state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('No one nearby yet'), findsNothing);
      expect(find.byType(SwipeCard), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 7. Action buttons present and correctly labelled
  // -------------------------------------------------------------------------

  group('DiscoverScreen — action buttons', () {
    testWidgets('Skip and Like buttons are present in the deck view', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Skip'), findsOneWidget);
      expect(find.bySemanticsLabel('Like'), findsOneWidget);
    });

    testWidgets('Skip button triggers onLeftSwipe', (tester) async {
      final leftSwiped = <SwipeRecord>[];
      await tester.pumpWidget(_buildScreen(onLeftSwipe: leftSwiped.add));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.pumpAndSettle();

      expect(leftSwiped, hasLength(1));
      expect(leftSwiped.first.direction, 'left');
    });

    testWidgets('Like button triggers onRightSwipe', (tester) async {
      final rightSwiped = <SwipeRecord>[];
      await tester.pumpWidget(_buildScreen(onRightSwipe: rightSwiped.add));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Like'));
      await tester.pumpAndSettle();

      expect(rightSwiped, hasLength(1));
      expect(rightSwiped.first.direction, 'right');
    });
  });

  // -------------------------------------------------------------------------
  // 8. Proximity pill shows current bucket label
  // -------------------------------------------------------------------------

  group('DiscoverScreen — proximity pill', () {
    testWidgets('proximity pill shows the label for the current bucket', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(bucket: ProximityBucket.sameDistrict),
      );
      await tester.pumpAndSettle();

      expect(find.text('Same district'), findsOneWidget);
    });

    testWidgets('proximity pill label reflects allThailand bucket', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(bucket: ProximityBucket.allThailand),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Thailand'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // F18 — incoming-interest badge on the candidate's card
  // -------------------------------------------------------------------------

  group('SwipeCard — incoming interest (F18)', () {
    testWidgets(
      'shows "Wants your {item}" badge for a candidate in the interestMap',
      (tester) async {
        final user = _makeUser(displayName: 'Cho');
        await tester.pumpWidget(
          _buildScreen(
            candidates: [user],
            itemsByUser: {
              user.uid: [_makeItem(name: 'Leather tote bag')],
            },
            interestMap: {
              user.uid: const IncomingInterest(
                itemId: 'item-9',
                itemName: 'Cow',
              ),
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wants your Cow'), findsOneWidget);
        // Candidate identity is still shown (prototype behaviour, not anonymous).
        expect(find.text('Cho'), findsWidgets);
      },
    );

    testWidgets('no badge when the candidate is absent from interestMap', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('Wants your'), findsNothing);
    });
  });
}
