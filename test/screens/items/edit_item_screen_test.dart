import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/screens/items/edit_item_screen.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/photo_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Fake [PhotoService] that returns a fixed URL without touching image picker
/// or Firebase Storage.
PhotoService _fakePhotoService() {
  return PhotoService(
    pickImage: () async => Uint8List.fromList([1, 2, 3]),
    compress:
        ({
          required Uint8List bytes,
          required int minWidth,
          required int minHeight,
          required int quality,
        }) async => bytes,
    upload: ({required String storagePath, required Uint8List bytes}) async =>
        'https://example.com/new.jpg',
  );
}

/// Captures calls to [updateItem] and [softDeleteItem] without touching
/// Firestore.
class _CapturingItemService extends ItemService {
  Map<String, dynamic>? lastUpdated;
  String? lastUpdatedId;
  String? lastDeletedId;

  _CapturingItemService()
    : super(
        itemDocWriter: (_) async => 'fake-id',
        itemDocUpdater: (_, _) async {},
        itemDocSoftDeleter: (_) async {},
      );

  @override
  Future<void> updateItem(
    String itemId, {
    required String name,
    required ItemCategory category,
    required ItemCondition condition,
    required String photoUrl,
    double? weight,
    String? description,
    String? wants,
  }) async {
    lastUpdatedId = itemId;
    lastUpdated = {
      'name': name,
      'category': category.value,
      'condition': condition.value,
      'photoUrl': photoUrl,
      'weight': weight,
      'description': description,
      'wants': wants,
    };
  }

  @override
  Future<void> softDeleteItem(String itemId) async {
    lastDeletedId = itemId;
  }
}

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

Item _fixtureItem({
  String id = 'item-001',
  String name = 'Leather tote bag',
  ItemCategory category = ItemCategory.clothing,
  ItemCondition condition = ItemCondition.likeNew,
  double? weight = 1.2,
  String? description = 'Barely used',
  String? wants = 'books',
  String photoUrl = 'https://example.com/photo.jpg',
  ItemStatus status = ItemStatus.active,
}) {
  return Item(
    id: id,
    ownerId: 'user-1',
    name: name,
    category: category,
    condition: condition,
    weight: weight,
    description: description,
    wants: wants,
    photoUrl: photoUrl,
    status: status,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required Item item,
  PhotoService? photoService,
  ItemService? itemService,
  String? uid = 'user-1',
  VoidCallback? onSaveSuccess,
  VoidCallback? onDeleteSuccess,
}) {
  return MaterialApp(
    initialRoute: '/edit',
    routes: {
      '/': (_) => const Scaffold(body: Text('home')),
      '/edit': (_) => EditItemScreen(
        item: item,
        photoService: photoService ?? _fakePhotoService(),
        itemService: itemService ?? _CapturingItemService(),
        getCurrentUid: () => uid,
        onSaveSuccess: onSaveSuccess,
        onDeleteSuccess: onDeleteSuccess,
      ),
    },
  );
}

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  final btn = find.byKey(const Key('submitButton'));
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> _tapDelete(WidgetTester tester) async {
  final btn = find.byKey(const Key('deleteButton'));
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests — WBS 6.4
// ---------------------------------------------------------------------------

void main() {
  group('EditItemScreen', () {
    // ── WBS 6.4 Test: edit pre-fills correctly from a fixture item ───────────

    testWidgets('pre-fills name, category, condition, description, wants', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final item = _fixtureItem(
        name: 'Leather tote bag',
        category: ItemCategory.clothing,
        condition: ItemCondition.likeNew,
        description: 'Barely used',
        wants: 'books',
      );

      await tester.pumpWidget(_buildScreen(item: item));

      // Name field should contain the item's name
      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('nameField')),
      );
      expect(
        nameField.controller?.text,
        equals('Leather tote bag'),
        reason: 'name should be pre-filled',
      );

      // Category row should show the item's category label
      await tester.ensureVisible(find.text('Clothing'));
      expect(find.text('Clothing'), findsOneWidget);

      // Condition pill for 'Like new' should be present
      await tester.ensureVisible(find.text('Like new'));
      expect(find.text('Like new'), findsOneWidget);

      // Description field should contain the item's description
      await tester.ensureVisible(find.byKey(const Key('descriptionField')));
      final descField = tester.widget<TextFormField>(
        find.byKey(const Key('descriptionField')),
      );
      expect(descField.controller?.text, equals('Barely used'));

      // Wants field should contain the item's wants
      await tester.ensureVisible(find.byKey(const Key('wantsField')));
      final wantsField = tester.widget<TextFormField>(
        find.byKey(const Key('wantsField')),
      );
      expect(wantsField.controller?.text, equals('books'));
    });

    testWidgets('pre-fills weight when item has a weight', (tester) async {
      _useLargeViewport(tester);
      final item = _fixtureItem(weight: 1.2);

      await tester.pumpWidget(_buildScreen(item: item));

      await tester.ensureVisible(find.byKey(const Key('weightField')));
      final weightField = tester.widget<TextFormField>(
        find.byKey(const Key('weightField')),
      );
      // Weight 1.2 → "1.2"
      expect(weightField.controller?.text, equals('1.2'));
    });

    testWidgets('photo field shows as filled when item has a photoUrl', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final item = _fixtureItem(photoUrl: 'https://example.com/photo.jpg');

      await tester.pumpWidget(_buildScreen(item: item));

      // The photo field should show the "Change" button overlay,
      // which only appears when hasPhoto == true (label changed in image-upload fix)
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('shows Edit item title and Save changes button', (
      tester,
    ) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen(item: _fixtureItem()));

      expect(find.text('Edit item'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('submitButton')));
      expect(find.text('Save changes'), findsOneWidget);
    });

    // ── WBS 6.4 Test: save triggers Firestore update with merged document ────

    testWidgets('save calls updateItem with correct merged document', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();
      bool saveCalled = false;

      final item = _fixtureItem(
        id: 'item-abc',
        name: 'Leather tote bag',
        category: ItemCategory.clothing,
        condition: ItemCondition.likeNew,
        weight: 1.2,
        description: 'Barely used',
        wants: 'books',
        photoUrl: 'https://example.com/photo.jpg',
      );

      await tester.pumpWidget(
        _buildScreen(
          item: item,
          itemService: capturing,
          onSaveSuccess: () => saveCalled = true,
        ),
      );

      // Edit the name
      await tester.enterText(
        find.byKey(const Key('nameField')),
        'Updated tote bag',
      );
      await tester.pump();

      await _tapSubmit(tester);

      expect(
        capturing.lastUpdated,
        isNotNull,
        reason: 'updateItem should have been called',
      );
      expect(capturing.lastUpdatedId, equals('item-abc'));
      expect(capturing.lastUpdated!['name'], equals('Updated tote bag'));
      expect(capturing.lastUpdated!['category'], equals('clothing'));
      expect(capturing.lastUpdated!['condition'], equals('like-new'));
      expect(
        capturing.lastUpdated!['photoUrl'],
        equals('https://example.com/photo.jpg'),
      );
      expect(saveCalled, isTrue);
    });

    testWidgets('save preserves all unedited fields in the merged document', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();

      final item = _fixtureItem(
        category: ItemCategory.books,
        condition: ItemCondition.good,
        weight: 0.5,
        description: 'Old description',
        wants: 'kitchenware',
      );

      await tester.pumpWidget(_buildScreen(item: item, itemService: capturing));

      // No edits — just tap save
      await _tapSubmit(tester);

      expect(capturing.lastUpdated!['category'], equals('books'));
      expect(capturing.lastUpdated!['condition'], equals('good'));
      expect(capturing.lastUpdated!['weight'], equals(0.5));
      expect(capturing.lastUpdated!['description'], equals('Old description'));
      expect(capturing.lastUpdated!['wants'], equals('kitchenware'));
    });

    // ── WBS 6.4 Test: delete with confirmation writes status: 'deleted' ──────

    testWidgets('delete with confirmation calls softDeleteItem', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();
      bool deleteCalled = false;

      final item = _fixtureItem(id: 'item-to-delete');

      await tester.pumpWidget(
        _buildScreen(
          item: item,
          itemService: capturing,
          onDeleteSuccess: () => deleteCalled = true,
        ),
      );

      // Tap delete — should show confirmation dialog
      await _tapDelete(tester);

      // Confirmation dialog should be visible
      expect(find.text('Delete item?'), findsOneWidget);

      // Tap the confirm button
      await tester.tap(find.byKey(const Key('deleteConfirmButton')));
      await tester.pumpAndSettle();

      expect(
        capturing.lastDeletedId,
        equals('item-to-delete'),
        reason: 'softDeleteItem should have been called with the item ID',
      );
      expect(deleteCalled, isTrue);
    });

    // ── WBS 6.4 Test: delete with cancel does nothing ────────────────────────

    testWidgets('delete with cancel does not call softDeleteItem', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();

      await tester.pumpWidget(
        _buildScreen(item: _fixtureItem(), itemService: capturing),
      );

      // Tap delete — dialog appears
      await _tapDelete(tester);

      expect(find.text('Delete item?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('deleteCancelButton')));
      await tester.pumpAndSettle();

      expect(
        capturing.lastDeletedId,
        isNull,
        reason: 'softDeleteItem should NOT have been called after cancel',
      );
    });

    // ── Additional structural checks ─────────────────────────────────────────

    testWidgets('delete button is visible in edit mode', (tester) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen(item: _fixtureItem()));

      await tester.ensureVisible(find.byKey(const Key('deleteButton')));
      expect(find.byKey(const Key('deleteButton')), findsOneWidget);
    });

    testWidgets('cancelling delete keeps the screen open', (tester) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen(item: _fixtureItem()));

      await _tapDelete(tester);
      await tester.tap(find.byKey(const Key('deleteCancelButton')));
      await tester.pumpAndSettle();

      // Screen should still show the edit form
      expect(find.text('Edit item'), findsOneWidget);
    });
  });
}
