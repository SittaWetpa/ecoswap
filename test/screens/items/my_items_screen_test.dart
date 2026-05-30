import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/screens/items/my_items_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a fake [Item] with sensible defaults. Only the fields relevant to
/// the My Items screen need to be supplied.
Item _fakeItem({
  required String id,
  required String name,
  ItemStatus status = ItemStatus.active,
  ItemCondition condition = ItemCondition.good,
}) {
  return Item(
    id: id,
    ownerId: 'user1',
    name: name,
    category: ItemCategory.books,
    condition: condition,
    photoUrl: '',
    status: status,
  );
}

/// Wraps [MyItemsScreen] in a [MaterialApp] with a named home route so that
/// any internal [Navigator.pop] calls don't throw.
Widget _buildScreen({
  required Stream<List<Item>> stream,
  VoidCallback? onAdd,
  void Function(Item)? onEdit,
}) {
  return MaterialApp(
    home: MyItemsScreen(
      // Supply a uid so the screen doesn't fall into the "not signed in" branch.
      getCurrentUid: () => 'user1',
      itemsStream: stream,
      onAdd: onAdd,
      onEdit: onEdit,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — WBS 6.3
// ---------------------------------------------------------------------------

void main() {
  group('MyItemsScreen', () {
    // ── Test 1: 3 active + 1 traded — 4 items rendered, traded is dimmed ─────

    testWidgets(
      'shows 4 items — 3 active and 1 traded, traded item is dimmed',
      (tester) async {
        // Use a tall viewport so all 4 grid tiles are rendered at once.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = StreamController<List<Item>>();

        await tester.pumpWidget(_buildScreen(stream: controller.stream));

        // Emit 3 active items and 1 traded item.
        final items = [
          _fakeItem(id: 'i1', name: 'Book One'),
          _fakeItem(id: 'i2', name: 'Book Two'),
          _fakeItem(id: 'i3', name: 'Book Three'),
          _fakeItem(id: 'i4', name: 'Old Jacket', status: ItemStatus.traded),
        ];
        controller.add(items);
        await tester.pump();

        // All 4 item names must be visible.
        expect(find.text('Book One'), findsOneWidget);
        expect(find.text('Book Two'), findsOneWidget);
        expect(find.text('Book Three'), findsOneWidget);
        expect(find.text('Old Jacket'), findsOneWidget);

        // The "Traded" status pill must appear for the traded item.
        expect(find.text('Traded'), findsOneWidget);

        // The traded item tile must be wrapped in an Opacity widget with
        // opacity < 1.0 (specifically 0.5 per the style guide).
        final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
        expect(
          opacityWidgets.any((o) => o.opacity < 1.0),
          isTrue,
          reason:
              'At least one Opacity widget with opacity < 1.0 expected for '
              'the traded item',
        );

        await controller.close();
      },
    );

    // ── Test 1b: traded items are view-only (no edit/delete) ─────────────────
    //
    // A traded item must not expose the edit affordance, and tapping its tile
    // must not invoke onEdit (which is also the only route to delete). Active
    // items keep their edit button.

    testWidgets('traded item has no edit button and is not tappable to edit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final edited = <String>[];
      final controller = StreamController<List<Item>>();

      await tester.pumpWidget(
        _buildScreen(
          stream: controller.stream,
          onEdit: (item) => edited.add(item.id),
        ),
      );

      controller.add([
        _fakeItem(id: 'active1', name: 'Active Book'),
        _fakeItem(
          id: 'traded1',
          name: 'Traded Book',
          status: ItemStatus.traded,
        ),
      ]);
      await tester.pump();

      // Exactly one edit button — for the active item only.
      expect(find.byTooltip('Edit Active Book'), findsOneWidget);
      expect(find.byTooltip('Edit Traded Book'), findsNothing);

      // Tapping the traded tile does not open edit (view-only).
      await tester.tap(find.text('Traded Book'));
      await tester.pump();
      expect(edited, isEmpty);

      // Tapping the active tile still opens edit.
      await tester.tap(find.text('Active Book'));
      await tester.pump();
      expect(edited, ['active1']);

      await controller.close();
    });

    // ── Test 2: empty stream shows empty state ────────────────────────────────

    testWidgets('shows empty state when stream has 0 items', (tester) async {
      final controller = StreamController<List<Item>>();

      await tester.pumpWidget(_buildScreen(stream: controller.stream));

      controller.add([]);
      await tester.pump();

      expect(find.text('Nothing to swap yet'), findsOneWidget);
      expect(find.text('Add your first item'), findsOneWidget);

      // Grid count text should NOT be visible.
      expect(find.textContaining('items · all visible'), findsNothing);

      await controller.close();
    });

    // ── Test 3: deleted items do not appear ───────────────────────────────────

    testWidgets('deleted items do not appear', (tester) async {
      final controller = StreamController<List<Item>>();

      await tester.pumpWidget(_buildScreen(stream: controller.stream));

      // Stream returns 1 active item and 1 deleted item.
      // The screen client-side filters out deleted items for safety.
      controller.add([
        _fakeItem(id: 'a1', name: 'Visible Item'),
        _fakeItem(id: 'd1', name: 'Deleted Item', status: ItemStatus.deleted),
      ]);
      await tester.pump();

      // Only the active item should be visible.
      expect(find.text('Visible Item'), findsOneWidget);
      expect(find.text('Deleted Item'), findsNothing);

      // Count line should say 1 item, not 2.
      expect(
        find.text('1 items · all visible to nearby swappers'),
        findsOneWidget,
      );

      await controller.close();
    });
  });
}
