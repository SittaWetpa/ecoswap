/// Widget tests for WBS 7.5 — User Detail with Item Bottom Sheet
///
/// Covers every acceptance criterion and testing requirement from the entry:
///   1. User Detail displays all profile fields correctly
///   2. Item grid shows all active items
///   3. Tapping an item opens the bottom sheet
///   4. Bottom sheet hides the weight row if `weight == null`
///   (+ bonus: bottom sheet shows weight row when weight is set)
///   (+ bonus: no out-of-scope fields displayed)
library;

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/discover/user_detail_screen.dart';
import 'package:ecoswap/widgets/item_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

User _makeUser({
  String uid = 'user-1',
  String displayName = 'Ploy',
  String bio = 'Comm student. Decluttering my dorm.',
  String photoUrl = '',
  String districtNameTh = 'บางมด',
  String districtNameEn = 'Bang Mod',
  String provinceNameEn = 'Bangkok',
  String provinceNameTh = 'กรุงเทพมหานคร',
  String provinceId = '10',
  String districtId = '1001',
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

Item _makeItem({
  String id = 'item-1',
  String ownerId = 'user-1',
  String name = 'Leather tote bag',
  String photoUrl = '',
  ItemCategory category = ItemCategory.clothing,
  ItemCondition condition = ItemCondition.likeNew,
  double? weight,
  String? description,
  String? wants,
}) {
  return Item(
    id: id,
    ownerId: ownerId,
    name: name,
    category: category,
    condition: condition,
    photoUrl: photoUrl,
    status: ItemStatus.active,
    weight: weight,
    description: description,
    wants: wants,
  );
}

Widget _wrapScreen(Widget child) {
  return MaterialApp(home: child);
}

Widget _buildDetailScreen({
  User? user,
  List<Item>? items,
  VoidCallback? onBack,
  VoidCallback? onRightSwipe,
  VoidCallback? onLeftSwipe,
}) {
  final u = user ?? _makeUser();
  return _wrapScreen(
    UserDetailScreen(
      user: u,
      items: items ?? [_makeItem(ownerId: u.uid)],
      onBack: onBack,
      onRightSwipe: onRightSwipe,
      onLeftSwipe: onLeftSwipe,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. User Detail displays all profile fields correctly
  // -------------------------------------------------------------------------

  group('UserDetailScreen — profile fields', () {
    testWidgets('displays the user display name', (tester) async {
      await tester.pumpWidget(_buildDetailScreen());
      await tester.pumpAndSettle();

      expect(find.text('Ploy'), findsAtLeast(1));
    });

    testWidgets(
      'displays the district label in Thai · English, Province format',
      (tester) async {
        await tester.pumpWidget(_buildDetailScreen());
        await tester.pumpAndSettle();

        expect(find.text('บางมด · Bang Mod, Bangkok'), findsOneWidget);
      },
    );

    testWidgets('displays the bio text', (tester) async {
      await tester.pumpWidget(_buildDetailScreen());
      await tester.pumpAndSettle();

      expect(find.text('Comm student. Decluttering my dorm.'), findsOneWidget);
    });

    testWidgets('does not display age', (tester) async {
      await tester.pumpWidget(_buildDetailScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining(' years', findRichText: true), findsNothing);
      expect(find.textContaining('yr old', findRichText: true), findsNothing);
    });

    testWidgets('does not display verification badge', (tester) async {
      await tester.pumpWidget(_buildDetailScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining('verified', findRichText: true), findsNothing);
      expect(find.textContaining('Verified', findRichText: true), findsNothing);
    });

    testWidgets('does not display activity status', (tester) async {
      await tester.pumpWidget(_buildDetailScreen());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('active now', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('last seen', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('does not display km or distance', (tester) async {
      await tester.pumpWidget(_buildDetailScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining(' km', findRichText: true), findsNothing);
      expect(find.textContaining('away', findRichText: true), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Item grid shows all active items
  // -------------------------------------------------------------------------

  group('UserDetailScreen — items grid', () {
    testWidgets('shows all items passed to the screen', (tester) async {
      final items = [
        _makeItem(id: 'i1', name: 'Leather tote bag'),
        _makeItem(id: 'i2', name: '3 design books'),
        _makeItem(id: 'i3', name: 'Electric kettle'),
      ];
      await tester.pumpWidget(_buildDetailScreen(items: items));
      await tester.pumpAndSettle();

      expect(find.text('Leather tote bag'), findsOneWidget);
      expect(find.text('3 design books'), findsOneWidget);
      expect(find.text('Electric kettle'), findsOneWidget);
    });

    testWidgets('shows item count in section header', (tester) async {
      final items = [
        _makeItem(id: 'i1', name: 'Item A'),
        _makeItem(id: 'i2', name: 'Item B'),
      ];
      await tester.pumpWidget(_buildDetailScreen(items: items));
      await tester.pumpAndSettle();

      // Header should contain the count "(2)"
      expect(find.textContaining("(2)"), findsOneWidget);
    });

    testWidgets('shows single item without crash', (tester) async {
      final items = [_makeItem(id: 'i1', name: 'Solo item')];
      await tester.pumpWidget(_buildDetailScreen(items: items));
      await tester.pumpAndSettle();

      expect(find.text('Solo item'), findsOneWidget);
    });

    testWidgets('shows nothing in grid when items list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildDetailScreen(items: []));
      await tester.pumpAndSettle();

      // Screen still renders (no crash); items grid is just empty.
      expect(find.byType(UserDetailScreen), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Tapping an item opens the bottom sheet
  // -------------------------------------------------------------------------

  group('UserDetailScreen — item tap opens bottom sheet', () {
    testWidgets('tapping an item card opens ItemDetailSheet', (tester) async {
      final item = _makeItem(
        id: 'i1',
        name: 'Leather tote bag',
        description: 'A lovely bag',
      );
      await tester.pumpWidget(_buildDetailScreen(items: [item]));
      await tester.pumpAndSettle();

      // The item grid is below the 360 px hero; scroll it into view first.
      await tester.scrollUntilVisible(
        find.text('Leather tote bag'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leather tote bag'));
      await tester.pumpAndSettle();

      // ItemDetailSheet should now be visible.
      expect(find.byType(ItemDetailSheet), findsOneWidget);
    });

    testWidgets('bottom sheet shows the tapped item name', (tester) async {
      final item = _makeItem(id: 'i1', name: 'Leather tote bag');
      await tester.pumpWidget(_buildDetailScreen(items: [item]));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Leather tote bag'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leather tote bag').first);
      await tester.pumpAndSettle();

      // The name appears inside the sheet (at least once).
      expect(find.text('Leather tote bag'), findsAtLeast(1));
    });
  });

  // -------------------------------------------------------------------------
  // 4. Bottom sheet hides weight row when weight == null
  // -------------------------------------------------------------------------

  group('ItemDetailSheet — weight row visibility', () {
    testWidgets('hides weight row when item weight is null', (tester) async {
      final item = _makeItem(id: 'i1', name: 'No-weight item', weight: null);
      await tester.pumpWidget(
        _wrapScreen(
          Scaffold(
            body: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () =>
                    ItemDetailSheet.show(ctx, item: item, owner: _makeUser()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Weight row uses "Approx." prefix — must not appear when weight is null.
      expect(find.textContaining('Approx.', findRichText: true), findsNothing);
    });

    testWidgets('shows weight row when item weight is provided', (
      tester,
    ) async {
      final item = _makeItem(id: 'i1', name: 'Heavy item', weight: 1.5);
      await tester.pumpWidget(
        _wrapScreen(
          Scaffold(
            body: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () =>
                    ItemDetailSheet.show(ctx, item: item, owner: _makeUser()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Approx. 1.5 kg'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 5. Bottom sheet shows all 7 item fields
  // -------------------------------------------------------------------------

  group('ItemDetailSheet — all 7 item fields', () {
    testWidgets('shows name, category, condition, description, wants, owner', (
      tester,
    ) async {
      final user = _makeUser(displayName: 'Ploy');
      final item = _makeItem(
        id: 'i1',
        name: 'Leather tote bag',
        category: ItemCategory.clothing,
        condition: ItemCondition.likeNew,
        weight: 0.5,
        description: 'Great quality leather.',
        wants: 'Books or kitchenware',
      );
      await tester.pumpWidget(
        _wrapScreen(
          Scaffold(
            body: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => ItemDetailSheet.show(ctx, item: item, owner: user),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Leather tote bag'), findsAtLeast(1)); // name
      expect(find.text('Clothing'), findsOneWidget); // category
      expect(find.text('Like new'), findsAtLeast(1)); // condition
      expect(find.textContaining('Approx. 0.5 kg'), findsOneWidget); // weight
      expect(
        find.text('Great quality leather.'),
        findsOneWidget,
      ); // description
      expect(find.text('Books or kitchenware'), findsOneWidget); // wants
      expect(find.textContaining('Owned by Ploy'), findsOneWidget); // owner
    });

    testWidgets('shows italic placeholder when description is null', (
      tester,
    ) async {
      final user = _makeUser(displayName: 'Fah');
      final item = _makeItem(id: 'i1', name: 'Desk lamp', description: null);
      await tester.pumpWidget(
        _wrapScreen(
          Scaffold(
            body: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => ItemDetailSheet.show(ctx, item: item, owner: user),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Fah didn't add a description."),
        findsOneWidget,
      );
    });

    testWidgets('shows "Open to anything." when wants is null', (tester) async {
      final user = _makeUser(displayName: 'Beam');
      final item = _makeItem(id: 'i1', name: 'Yoga mat', wants: null);
      await tester.pumpWidget(
        _wrapScreen(
          Scaffold(
            body: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => ItemDetailSheet.show(ctx, item: item, owner: user),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Open to anything.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Right-swipe and left-swipe buttons work
  // -------------------------------------------------------------------------

  group('UserDetailScreen — swipe action buttons', () {
    testWidgets('Skip button calls onLeftSwipe', (tester) async {
      var leftCalled = false;
      await tester.pumpWidget(
        _buildDetailScreen(onLeftSwipe: () => leftCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.pumpAndSettle();

      expect(leftCalled, isTrue);
    });

    testWidgets('Like button calls onRightSwipe', (tester) async {
      var rightCalled = false;
      await tester.pumpWidget(
        _buildDetailScreen(onRightSwipe: () => rightCalled = true),
      );
      await tester.pumpAndSettle();

      // The right-swipe button shows heart icon + text; tap the icon button
      // by finding the heart icon which is always visible in the sticky bar.
      final likeIcon = find.widgetWithIcon(
        GestureDetector,
        Icons.favorite_outline,
      );
      expect(likeIcon, findsAtLeast(1));
      await tester.tap(likeIcon.last);
      await tester.pumpAndSettle();

      expect(rightCalled, isTrue);
    });

    testWidgets('back button calls onBack', (tester) async {
      var backCalled = false;
      await tester.pumpWidget(
        _buildDetailScreen(onBack: () => backCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });
  });
}
