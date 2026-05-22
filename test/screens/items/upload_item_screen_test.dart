import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/screens/items/upload_item_screen.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/photo_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A [PhotoService] whose picker immediately returns a fake URL without
/// touching the real image picker or Firebase Storage.
PhotoService _fakePhotoService({bool cancel = false}) {
  return PhotoService(
    pickImage: () async => cancel ? null : Uint8List.fromList([1, 2, 3, 4, 5]),
    compress:
        ({
          required Uint8List bytes,
          required int minWidth,
          required int minHeight,
          required int quality,
        }) async => bytes,
    upload: ({required String storagePath, required Uint8List bytes}) async =>
        'https://example.com/item.jpg',
  );
}

/// Captures the last call to [ItemService.createItem].
class _CapturingItemService extends ItemService {
  Map<String, dynamic>? lastWritten;

  _CapturingItemService() : super(itemDocWriter: (_) async => 'fake-item-id');

  @override
  Future<String> createItem({
    required String ownerId,
    required String name,
    required ItemCategory category,
    required ItemCondition condition,
    required String photoUrl,
    double? weight,
    String? description,
    String? wants,
  }) async {
    lastWritten = {
      'ownerId': ownerId,
      'name': name,
      'category': category.value,
      'condition': condition.value,
      'weight': weight,
      'description': description,
      'wants': wants,
      'photoUrl': photoUrl,
      'status': ItemStatus.active.value,
    };
    return 'fake-item-id';
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [UploadItemScreen] in a [MaterialApp] that includes a named route
/// for the screen being popped to, so [Navigator.pop] doesn't throw.
Widget _buildScreen({
  PhotoService? photoService,
  ItemService? itemService,
  String? uid = 'user-test-uid',
  VoidCallback? onSubmitSuccess,
}) {
  return MaterialApp(
    // Provide a home so Navigator.pop has somewhere to go
    initialRoute: '/upload',
    routes: {
      '/': (_) => const Scaffold(body: Text('home')),
      '/upload': (_) => UploadItemScreen(
        photoService: photoService ?? _fakePhotoService(),
        itemService: itemService ?? _CapturingItemService(),
        getCurrentUid: () => uid,
        onSubmitSuccess: onSubmitSuccess,
      ),
    },
  );
}

/// Sets a tall viewport so the full scrollable form renders without clipping.
/// Must be called at the start of each [testWidgets] body.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Taps the photo field by key.
Future<void> _tapPhoto(WidgetTester tester) async {
  final photoFinder = find.byKey(const Key('photoField'));
  await tester.ensureVisible(photoFinder);
  await tester.pump();
  await tester.tap(photoFinder);
  await tester.pumpAndSettle();
}

/// Opens the category bottom sheet and picks [cat].
Future<void> _pickCategory(WidgetTester tester, ItemCategory cat) async {
  // Ensure the category row is on screen, then tap it.
  final catRow = find.text('Select a category');
  await tester.ensureVisible(catRow);
  await tester.pump();
  await tester.tap(catRow);
  await tester.pumpAndSettle();

  // Bottom sheet is now open. Ensure the target option is visible, then tap.
  final itemKey = Key('categoryOption_${cat.value}');
  await tester.ensureVisible(find.byKey(itemKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(itemKey));
  await tester.pumpAndSettle();
}

/// Taps a condition pill by label.
Future<void> _pickCondition(WidgetTester tester, String label) async {
  final pill = find.text(label);
  await tester.ensureVisible(pill);
  await tester.pump();
  await tester.tap(pill);
  await tester.pump();
}

/// Scrolls to and taps the submit button.
Future<void> _tapSubmit(WidgetTester tester) async {
  final btn = find.byKey(const Key('submitButton'));
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests — WBS 6.2
// ---------------------------------------------------------------------------

void main() {
  group('UploadItemScreen', () {
    // ── Acceptance: required field validation ────────────────────────────────

    testWidgets('submit with missing photo shows photo validation error', (
      tester,
    ) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(
        _buildScreen(photoService: _fakePhotoService(cancel: true)),
      );

      // Attempt to pick photo (picker cancels → no photo)
      await _tapPhoto(tester);

      // Fill other required fields
      await tester.enterText(find.byKey(const Key('nameField')), 'My item');
      await tester.pump();

      await _pickCategory(tester, ItemCategory.books);
      await _pickCondition(tester, 'Good');

      await _tapSubmit(tester);

      expect(find.text('A photo is required.'), findsOneWidget);
    });

    testWidgets('submit with missing item name shows name validation error', (
      tester,
    ) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen());

      await _tapPhoto(tester);
      await _pickCategory(tester, ItemCategory.clothing);
      await _pickCondition(tester, 'New');

      // Submit without entering a name
      await _tapSubmit(tester);

      expect(find.text('Item name is required.'), findsOneWidget);
    });

    testWidgets(
      'submit with missing category shows category validation error',
      (tester) async {
        _useLargeViewport(tester);
        await tester.pumpWidget(_buildScreen());

        await _tapPhoto(tester);

        await tester.enterText(find.byKey(const Key('nameField')), 'My item');
        await tester.pump();

        // Condition but NO category
        await _pickCondition(tester, 'Used');

        await _tapSubmit(tester);

        expect(find.text('Please select a category.'), findsOneWidget);
      },
    );

    testWidgets(
      'submit with missing condition shows condition validation error',
      (tester) async {
        _useLargeViewport(tester);
        await tester.pumpWidget(_buildScreen());

        await _tapPhoto(tester);

        await tester.enterText(find.byKey(const Key('nameField')), 'My item');
        await tester.pump();

        // Category but NO condition
        await _pickCategory(tester, ItemCategory.electronics);

        await _tapSubmit(tester);

        expect(find.text('Please select a condition.'), findsOneWidget);
      },
    );

    // ── Acceptance: correct Firestore doc shape ──────────────────────────────

    testWidgets('submit with all fields creates item with correct shape', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();
      bool successCalled = false;

      await tester.pumpWidget(
        _buildScreen(
          itemService: capturing,
          onSubmitSuccess: () => successCalled = true,
        ),
      );

      await _tapPhoto(tester);

      await tester.enterText(
        find.byKey(const Key('nameField')),
        'Leather tote bag',
      );
      await tester.pump();

      await _pickCategory(tester, ItemCategory.clothing);
      await _pickCondition(tester, 'Like new');

      await tester.enterText(find.byKey(const Key('weightField')), '1.2');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('descriptionField')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('descriptionField')),
        'Barely used, great condition',
      );
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('wantsField')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('wantsField')),
        'books or kitchenware',
      );
      await tester.pump();

      await _tapSubmit(tester);

      expect(
        capturing.lastWritten,
        isNotNull,
        reason: 'createItem should have been called',
      );
      expect(capturing.lastWritten!['name'], equals('Leather tote bag'));
      expect(capturing.lastWritten!['category'], equals('clothing'));
      expect(capturing.lastWritten!['condition'], equals('like-new'));
      expect(capturing.lastWritten!['status'], equals('active'));
      expect(capturing.lastWritten!['ownerId'], equals('user-test-uid'));
      expect(
        capturing.lastWritten!['photoUrl'],
        equals('https://example.com/item.jpg'),
      );
      expect(successCalled, isTrue);
    });

    // ── Acceptance: weight blank stores null ─────────────────────────────────

    testWidgets('weight left blank writes null to Firestore', (tester) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();

      await tester.pumpWidget(_buildScreen(itemService: capturing));

      await _tapPhoto(tester);

      await tester.enterText(find.byKey(const Key('nameField')), 'Old kettle');
      await tester.pump();

      await _pickCategory(tester, ItemCategory.kitchenware);
      await _pickCondition(tester, 'Used');

      // Do NOT enter any weight

      await _tapSubmit(tester);

      expect(capturing.lastWritten, isNotNull);
      expect(capturing.lastWritten!['weight'], isNull);
    });

    // ── Acceptance: all 7 categories produce a valid document ────────────────

    for (final cat in ItemCategory.values) {
      testWidgets('category ${cat.value} produces valid document', (
        tester,
      ) async {
        _useLargeViewport(tester);
        final capturing = _CapturingItemService();

        await tester.pumpWidget(_buildScreen(itemService: capturing));

        await _tapPhoto(tester);

        await tester.enterText(find.byKey(const Key('nameField')), 'Test item');
        await tester.pump();

        await _pickCategory(tester, cat);
        await _pickCondition(tester, 'Good');

        await _tapSubmit(tester);

        expect(
          capturing.lastWritten,
          isNotNull,
          reason: 'Category ${cat.value} should produce a written doc',
        );
        expect(capturing.lastWritten!['category'], equals(cat.value));
        expect(capturing.lastWritten!['status'], equals('active'));
      });
    }

    // ── Acceptance: status is always 'active' on creation ───────────────────

    testWidgets('status is always written as active on creation', (
      tester,
    ) async {
      _useLargeViewport(tester);
      final capturing = _CapturingItemService();

      await tester.pumpWidget(_buildScreen(itemService: capturing));

      await _tapPhoto(tester);

      await tester.enterText(find.byKey(const Key('nameField')), 'Yoga mat');
      await tester.pump();

      await _pickCategory(tester, ItemCategory.household);
      await _pickCondition(tester, 'New');

      await _tapSubmit(tester);

      expect(capturing.lastWritten!['status'], equals('active'));
    });

    // ── Acceptance: all 4 conditions selectable ──────────────────────────────

    for (final cond in ItemCondition.values) {
      testWidgets(
        'condition ${cond.value} is selectable and written correctly',
        (tester) async {
          _useLargeViewport(tester);
          final capturing = _CapturingItemService();

          await tester.pumpWidget(_buildScreen(itemService: capturing));

          await _tapPhoto(tester);

          await tester.enterText(
            find.byKey(const Key('nameField')),
            'Test item',
          );
          await tester.pump();

          await _pickCategory(tester, ItemCategory.books);
          await _pickCondition(tester, cond.label);

          await _tapSubmit(tester);

          expect(
            capturing.lastWritten,
            isNotNull,
            reason: 'Condition ${cond.value} should produce a written doc',
          );
          expect(capturing.lastWritten!['condition'], equals(cond.value));
        },
      );
    }

    // ── Screen structure ─────────────────────────────────────────────────────

    testWidgets('screen renders title and submit button', (tester) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen());

      expect(find.text('Add an item'), findsOneWidget);
      expect(find.text('Add to my swaps'), findsOneWidget);
    });

    testWidgets('7 field labels are present', (tester) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      // Scroll to each label in turn to confirm it's in the widget tree
      final labels = [
        'Photo',
        'What is it?',
        'Category',
        'Condition',
        'Weight',
        'Description (optional)',
        'What would you like in return?',
      ];
      for (final label in labels) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Label "$label" should be visible',
        );
      }
    });

    testWidgets('all 4 condition pills are visible', (tester) async {
      _useLargeViewport(tester);
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      for (final cond in ItemCondition.values) {
        await tester.ensureVisible(find.text(cond.label));
        await tester.pump();
        expect(find.text(cond.label), findsOneWidget);
      }
    });

    // ── Item model unit tests ────────────────────────────────────────────────

    test('Item.fromJson handles weight: null correctly', () {
      final json = {
        'ownerId': 'uid-1',
        'name': 'Test item',
        'category': 'clothing',
        'condition': 'new',
        'weight': null,
        'description': null,
        'wants': null,
        'photoUrl': 'https://example.com/photo.jpg',
        'status': 'active',
        'createdAt': null,
      };

      final item = Item.fromJson(json, id: 'item-1');
      expect(item.weight, isNull);
    });

    test('Item.fromJson round-trips through toJson with no data loss', () {
      final original = Item(
        id: 'item-abc',
        ownerId: 'user-xyz',
        name: 'Electric kettle',
        category: ItemCategory.kitchenware,
        condition: ItemCondition.likeNew,
        weight: 1.2,
        description: 'Barely used',
        wants: 'books',
        photoUrl: 'https://example.com/photo.jpg',
        status: ItemStatus.active,
      );

      final json = original.toJson();

      final restored = Item.fromJson({
        'ownerId': json['ownerId'],
        'name': json['name'],
        'category': json['category'],
        'condition': json['condition'],
        'weight': json['weight'],
        'description': json['description'],
        'wants': json['wants'],
        'photoUrl': json['photoUrl'],
        'status': json['status'],
        'createdAt': null,
      }, id: original.id);

      expect(restored.id, equals(original.id));
      expect(restored.ownerId, equals(original.ownerId));
      expect(restored.name, equals(original.name));
      expect(restored.category, equals(original.category));
      expect(restored.condition, equals(original.condition));
      expect(restored.weight, equals(original.weight));
      expect(restored.description, equals(original.description));
      expect(restored.wants, equals(original.wants));
      expect(restored.photoUrl, equals(original.photoUrl));
      expect(restored.status, equals(original.status));
    });

    test('all 7 ItemCategory values are defined', () {
      expect(ItemCategory.values.length, equals(7));
      final values = ItemCategory.values.map((c) => c.value).toSet();
      expect(
        values,
        containsAll([
          'clothing',
          'books',
          'kitchenware',
          'household',
          'electronics',
          'furniture',
          'other',
        ]),
      );
    });

    test('all 4 ItemCondition values are defined', () {
      expect(ItemCondition.values.length, equals(4));
      final values = ItemCondition.values.map((c) => c.value).toSet();
      expect(values, containsAll(['new', 'like-new', 'good', 'used']));
    });
  });
}
