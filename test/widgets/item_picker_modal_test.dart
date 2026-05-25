/// Widget tests for WBS 8.2 — Item Picker Modal on Swipe-Right
///
/// Covers every acceptance criterion and testing requirement listed in the
/// WBS 8.2 entry:
///   1. Modal shows the correct list of active items
///   2. Tapping item A then item B leaves only B selected (single-select)
///   3. Confirm button is disabled when no item is selected
///   4. Cancel does not write a swipe
///   5. Confirm writes a swipe with the correct [desiredItemId]
library;

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/services/swipe_service.dart';
import 'package:ecoswap/widgets/item_picker_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Builds a minimal active [Item] for testing.
Item _makeItem({
  String id = 'item-1',
  String ownerId = 'user-target',
  String name = 'Electric kettle',
  ItemCategory category = ItemCategory.kitchenware,
  ItemCondition condition = ItemCondition.likeNew,
}) {
  return Item(
    id: id,
    ownerId: ownerId,
    name: name,
    category: category,
    condition: condition,
    photoUrl: '',
    status: ItemStatus.active,
  );
}

/// Creates a [SwipeService] whose Firestore add operation is replaced by a
/// simple closure that appends each written document to [captured].
///
/// No real Firebase project required.
SwipeService _fakeSwipeService({
  required List<Map<String, dynamic>> captured,
  String currentUserId = 'user-me',
}) {
  return SwipeService(
    currentUserId: currentUserId,
    swipeDocAdder: (data) async {
      captured.add(Map<String, dynamic>.from(data));
      return 'fake-swipe-id';
    },
  );
}

/// Wraps [child] in a [MaterialApp] with a tall [MediaQuery] so the
/// [GridView] inside the modal has enough vertical space for all cards.
///
/// 1200 × 900 logical pixels matches a tablet-ish viewport; it ensures that
/// two-column grids with 2-3 items are fully rendered and tappable without
/// needing to scroll in most test cases.
Widget _wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1200, 900)),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Pumps an [ItemPickerModal] directly (not via [showModalBottomSheet]) so
/// the widget tree is simpler to drive in tests.
Widget _buildModal({
  String targetUserName = 'Fah',
  String targetUserId = 'user-target',
  List<Item>? items,
  required SwipeService swipeService,
}) {
  return _wrap(
    ItemPickerModal(
      targetUserName: targetUserName,
      targetUserId: targetUserId,
      items:
          items ??
          [
            _makeItem(id: 'item-1', name: 'Electric kettle'),
            _makeItem(
              id: 'item-2',
              name: 'Desk lamp',
              category: ItemCategory.household,
              condition: ItemCondition.good,
            ),
          ],
      swipeService: swipeService,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Modal shows correct list of active items
  // -------------------------------------------------------------------------

  group('ItemPickerModal — item list', () {
    testWidgets('shows all items passed to the modal', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      final items = [
        _makeItem(id: 'item-1', name: 'Electric kettle'),
        _makeItem(
          id: 'item-2',
          name: 'Desk lamp',
          category: ItemCategory.household,
        ),
        _makeItem(
          id: 'item-3',
          name: 'Yoga mat',
          category: ItemCategory.household,
          condition: ItemCondition.newCondition,
        ),
      ];

      await tester.pumpWidget(_buildModal(items: items, swipeService: service));
      await tester.pumpAndSettle();

      // Scroll until each item name is visible in case it is off-screen.
      await tester.scrollUntilVisible(
        find.text('Electric kettle'),
        50,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Electric kettle'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Desk lamp'),
        50,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Desk lamp'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Yoga mat'),
        50,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Yoga mat'), findsOneWidget);
    });

    testWidgets('shows target user name in heading', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      await tester.pumpWidget(
        _buildModal(targetUserName: 'Fah', swipeService: service),
      );
      await tester.pumpAndSettle();

      // Heading uses the possessive form: "What of Fah's do you want?"
      expect(find.textContaining("Fah's"), findsWidgets);
    });

    testWidgets('renders an ItemPickCard for each item', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      final items = [
        _makeItem(id: 'item-1', name: 'Kettle'),
        _makeItem(id: 'item-2', name: 'Lamp', category: ItemCategory.household),
      ];

      await tester.pumpWidget(_buildModal(items: items, swipeService: service));
      await tester.pumpAndSettle();

      expect(find.byType(ItemPickCard), findsNWidgets(2));
    });
  });

  // -------------------------------------------------------------------------
  // 2. Single-select: tapping item A then item B leaves only B selected
  // -------------------------------------------------------------------------

  group('ItemPickerModal — single-select', () {
    testWidgets('tapping item A then item B selects only item B', (
      tester,
    ) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      final itemA = _makeItem(id: 'item-a', name: 'Kettle');
      final itemB = _makeItem(
        id: 'item-b',
        name: 'Desk lamp',
        category: ItemCategory.household,
      );

      await tester.pumpWidget(
        _buildModal(items: [itemA, itemB], swipeService: service),
      );
      await tester.pumpAndSettle();

      // Tap item A — ensure it is on-screen first.
      await tester.ensureVisible(find.byKey(const ValueKey('item-a')));
      await tester.tap(find.byKey(const ValueKey('item-a')));
      await tester.pump();

      // Tap item B.
      await tester.ensureVisible(find.byKey(const ValueKey('item-b')));
      await tester.tap(find.byKey(const ValueKey('item-b')));
      await tester.pump();

      // Only item B's card should be selected.
      final cards = tester
          .widgetList<ItemPickCard>(find.byType(ItemPickCard))
          .toList();

      expect(cards.length, 2);
      final cardA = cards.firstWhere((c) => c.item.id == 'item-a');
      final cardB = cards.firstWhere((c) => c.item.id == 'item-b');
      expect(cardA.selected, isFalse, reason: 'item A should not be selected');
      expect(cardB.selected, isTrue, reason: 'item B should be selected');
    });

    testWidgets('no item is selected on initial render', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      await tester.pumpWidget(_buildModal(swipeService: service));
      await tester.pumpAndSettle();

      final cards = tester
          .widgetList<ItemPickCard>(find.byType(ItemPickCard))
          .toList();

      for (final card in cards) {
        expect(card.selected, isFalse);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 3. Confirm button disabled when no selection
  // -------------------------------------------------------------------------

  group('ItemPickerModal — confirm button state', () {
    testWidgets('confirm button is disabled with no selection', (tester) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      await tester.pumpWidget(_buildModal(swipeService: service));
      await tester.pumpAndSettle();

      // ElevatedButton.onPressed is null when disabled.
      final buttonFinder = find.widgetWithText(
        ElevatedButton,
        'Send interest to Fah',
      );
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(
        button.onPressed,
        isNull,
        reason: 'Confirm must be disabled until an item is selected',
      );
    });

    testWidgets('confirm button is enabled after selecting an item', (
      tester,
    ) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      await tester.pumpWidget(_buildModal(swipeService: service));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('item-1')));
      await tester.tap(find.byKey(const ValueKey('item-1')));
      await tester.pump();

      final buttonFinder = find.widgetWithText(
        ElevatedButton,
        'Send interest to Fah',
      );
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(
        button.onPressed,
        isNotNull,
        reason: 'Confirm must be enabled once an item is selected',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 4. Cancel does not write a swipe
  // -------------------------------------------------------------------------

  group('ItemPickerModal — cancel', () {
    testWidgets('tapping close button does not write a swipe doc', (
      tester,
    ) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      await tester.pumpWidget(_buildModal(swipeService: service));
      await tester.pumpAndSettle();

      // Tap an item first so there IS a selection.
      await tester.ensureVisible(find.byKey(const ValueKey('item-1')));
      await tester.tap(find.byKey(const ValueKey('item-1')));
      await tester.pump();

      // Tap the close (X) button — semantics label is 'Close'.
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();

      expect(
        captured,
        isEmpty,
        reason: 'Cancelling must not write any swipe document',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 5. Confirm writes swipe with correct desiredItemId
  // -------------------------------------------------------------------------

  group('ItemPickerModal — confirm writes swipe', () {
    testWidgets(
      'confirming with item B writes a right-swipe with desiredItemId = B',
      (tester) async {
        final captured = <Map<String, dynamic>>[];
        final service = _fakeSwipeService(
          captured: captured,
          currentUserId: 'user-me',
        );

        final itemA = _makeItem(id: 'item-a', name: 'Kettle');
        final itemB = _makeItem(
          id: 'item-b',
          name: 'Desk lamp',
          category: ItemCategory.household,
        );

        await tester.pumpWidget(
          _buildModal(
            targetUserId: 'user-target',
            items: [itemA, itemB],
            swipeService: service,
          ),
        );
        await tester.pumpAndSettle();

        // Select item B.
        await tester.ensureVisible(find.byKey(const ValueKey('item-b')));
        await tester.tap(find.byKey(const ValueKey('item-b')));
        await tester.pump();

        // Scroll the confirm button into view and tap it.
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Send interest to Fah'),
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Send interest to Fah'),
        );
        await tester.pumpAndSettle();

        expect(
          captured,
          hasLength(1),
          reason: 'Exactly one swipe doc expected',
        );
        final doc = captured.first;
        expect(doc['direction'], equals('right'));
        expect(doc['desiredItemId'], equals('item-b'));
        expect(doc['targetUserId'], equals('user-target'));
        expect(doc['swiperId'], equals('user-me'));
      },
    );

    testWidgets('tapping confirm writes direction right (not left)', (
      tester,
    ) async {
      final captured = <Map<String, dynamic>>[];
      final service = _fakeSwipeService(captured: captured);

      await tester.pumpWidget(_buildModal(swipeService: service));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('item-1')));
      await tester.tap(find.byKey(const ValueKey('item-1')));
      await tester.pump();

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Send interest to Fah'),
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Send interest to Fah'),
      );
      await tester.pumpAndSettle();

      expect(captured.first['direction'], equals('right'));
    });
  });
}
