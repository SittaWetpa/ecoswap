import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/screens/items/upload_item_screen.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/photo_service.dart';

// ---------------------------------------------------------------------------
// Fake ItemService — captures items written via createItem()
// ---------------------------------------------------------------------------

class _FakeItemService extends ItemService {
  final List<Item> created = [];

  _FakeItemService() : super(collectionRef: (_) => throw UnimplementedError());

  @override
  Future<String> createItem(Item item) async {
    created.add(item);
    return 'fake-item-id';
  }
}

// ---------------------------------------------------------------------------
// Photo service factories
// ---------------------------------------------------------------------------

/// Returns a fake URL immediately (simulates user picking a photo).
PhotoService _fakePhotoService() => PhotoService(
      pickImage: () async => Uint8List(1),
      compress: ({
        required Uint8List bytes,
        required int minWidth,
        required int minHeight,
        required int quality,
      }) async =>
          Uint8List(1),
      upload: ({
        required String storagePath,
        required Uint8List bytes,
      }) async =>
          'https://example.com/fake-photo.jpg',
    );

/// Returns null (simulates user cancelling the photo picker).
PhotoService _cancelPhotoService() => PhotoService(
      pickImage: () async => null,
      compress: ({
        required Uint8List bytes,
        required int minWidth,
        required int minHeight,
        required int quality,
      }) async =>
          Uint8List(0),
      upload: ({
        required String storagePath,
        required Uint8List bytes,
      }) async =>
          '',
    );

// ---------------------------------------------------------------------------
// Build helper
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required _FakeItemService itemService,
  PhotoService? photoService,
  String ownerId = 'uid-test',
}) {
  return MaterialApp(
    home: UploadItemScreen(
      ownerId: ownerId,
      itemService: itemService,
      photoService: photoService ?? _fakePhotoService(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Interaction helpers
// ---------------------------------------------------------------------------

/// Triggers the fake photo pick by tapping the "Add a photo" area.
Future<void> _pickPhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('photo_field_empty')));
  await tester.pumpAndSettle();
}

/// Scrolls to the category row, opens the bottom sheet, scrolls to the item,
/// taps it, and waits for the sheet to fully dismiss.
Future<void> _pickCategory(WidgetTester tester, ItemCategory category) async {
  final categoryRowFinder = find.byKey(const Key('category_row'));
  await tester.ensureVisible(categoryRowFinder);
  await tester.pumpAndSettle();
  await tester.tap(categoryRowFinder);
  await tester.pumpAndSettle();

  // The bottom sheet is now open. Scroll within the sheet until the category
  // label is visible (some categories like Electronics/Furniture/Other are
  // below the fold in a 600px test viewport).
  final labelFinder = find.text(category.label);
  await tester.scrollUntilVisible(labelFinder, 100,
      scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
  await tester.tap(labelFinder.first);
  // Wait for the sheet to fully dismiss before continuing.
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

/// Scrolls to the condition pills and taps the correct one.
Future<void> _pickCondition(WidgetTester tester, ItemCondition condition) async {
  final conditionText = find.text(condition.label);
  await tester.ensureVisible(conditionText);
  await tester.pumpAndSettle();
  await tester.tap(conditionText);
  await tester.pump();
}

/// Fills all required fields: photo, name, category, condition.
Future<void> _fillRequiredFields(
  WidgetTester tester, {
  String name = 'Leather tote bag',
  ItemCategory category = ItemCategory.clothing,
  ItemCondition condition = ItemCondition.likeNew,
}) async {
  await _pickPhoto(tester);

  final nameFinder = find.byKey(const Key('field_name'));
  await tester.ensureVisible(nameFinder);
  await tester.enterText(nameFinder, name);
  await tester.pump();

  await _pickCategory(tester, category);
  await _pickCondition(tester, condition);
}

/// Scrolls to and taps the submit button.
Future<void> _tapSubmit(WidgetTester tester) async {
  final submitFinder = find.byKey(const Key('btn_submit'));
  await tester.ensureVisible(submitFinder);
  await tester.pumpAndSettle();
  await tester.tap(submitFinder);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UploadItemScreen — WBS 6.2', () {
    // -----------------------------------------------------------------------
    // 1. Submit with missing required field — submit button is disabled
    // -----------------------------------------------------------------------

    testWidgets(
      'submit button is disabled when no fields are filled',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_submit')),
        );
        expect(button.onPressed, isNull,
            reason: 'Submit must be disabled when required fields are missing');
        expect(itemService.created, isEmpty);
      },
    );

    testWidgets(
      'submit button is disabled when photo is missing',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(
          _buildScreen(
            itemService: itemService,
            photoService: _cancelPhotoService(),
          ),
        );

        // Fill name
        await tester.enterText(find.byKey(const Key('field_name')), 'Test item');
        await tester.pump();

        // Select category
        final categoryRowFinder = find.byKey(const Key('category_row'));
        await tester.ensureVisible(categoryRowFinder);
        await tester.pumpAndSettle();
        await tester.tap(categoryRowFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text(ItemCategory.clothing.label).first);
        await tester.pumpAndSettle();

        // Select condition
        await _pickCondition(tester, ItemCondition.newItem);

        // Button must be disabled (photo was never set because picker returned null)
        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_submit')),
        );
        expect(button.onPressed, isNull,
            reason: 'Submit must be disabled when photo is missing');
        expect(itemService.created, isEmpty);
      },
    );

    testWidgets(
      'submit button is disabled when name is empty',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        await _pickPhoto(tester);
        // Do not enter name
        await _pickCategory(tester, ItemCategory.books);
        await _pickCondition(tester, ItemCondition.good);

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_submit')),
        );
        expect(button.onPressed, isNull,
            reason: 'Submit must be disabled when name is empty');
        expect(itemService.created, isEmpty);
      },
    );

    testWidgets(
      'submit button is disabled when category is not selected',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        await _pickPhoto(tester);
        await tester.enterText(find.byKey(const Key('field_name')), 'My item');
        await tester.pump();
        // No category selected
        await _pickCondition(tester, ItemCondition.used);

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_submit')),
        );
        expect(button.onPressed, isNull,
            reason: 'Submit must be disabled when category is not selected');
        expect(itemService.created, isEmpty);
      },
    );

    testWidgets(
      'name field shows inline validation error after text is entered then cleared',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        final nameFinder = find.byKey(const Key('field_name'));
        await tester.ensureVisible(nameFinder);

        // Type something so autovalidateMode kicks in, then clear it.
        await tester.enterText(nameFinder, 'abc');
        await tester.pump();
        await tester.enterText(nameFinder, '');
        await tester.pump();

        expect(
          find.text('Item name is required'),
          findsOneWidget,
          reason: 'Inline validation error must be rendered when name is cleared',
        );
        expect(itemService.created, isEmpty);
      },
    );

    // -----------------------------------------------------------------------
    // 2. Submit with all fields creates Firestore doc with correct shape
    // -----------------------------------------------------------------------

    testWidgets(
      'submit with all required fields creates item with correct shape',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        await _fillRequiredFields(
          tester,
          name: 'Leather tote bag',
          category: ItemCategory.clothing,
          condition: ItemCondition.likeNew,
        );

        await _tapSubmit(tester);

        expect(itemService.created, hasLength(1));
        final item = itemService.created.first;

        expect(item.ownerId, equals('uid-test'));
        expect(item.name, equals('Leather tote bag'));
        expect(item.category, equals(ItemCategory.clothing));
        expect(item.condition, equals(ItemCondition.likeNew));
        expect(item.status, equals('active'));
        expect(item.photoUrl, equals('https://example.com/fake-photo.jpg'));
      },
    );

    testWidgets(
      'submit includes optional description and wants when provided',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        await _fillRequiredFields(tester);

        final descFinder = find.byKey(const Key('field_description'));
        await tester.ensureVisible(descFinder);
        await tester.enterText(descFinder, 'A great bag in perfect condition');
        await tester.pump();

        final wantsFinder = find.byKey(const Key('field_wants'));
        await tester.ensureVisible(wantsFinder);
        await tester.enterText(wantsFinder, 'books or kitchenware');
        await tester.pump();

        await _tapSubmit(tester);

        expect(itemService.created, hasLength(1));
        final item = itemService.created.first;
        expect(item.description, equals('A great bag in perfect condition'));
        expect(item.wants, equals('books or kitchenware'));
      },
    );

    // -----------------------------------------------------------------------
    // 3. Weight left blank writes null to Firestore
    // -----------------------------------------------------------------------

    testWidgets(
      'weight left blank stores null — does NOT store typical weight',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        await _fillRequiredFields(
          tester,
          category: ItemCategory.clothing,
          condition: ItemCondition.newItem,
        );

        // Weight field is present but we do NOT enter a value
        expect(find.byKey(const Key('field_weight')), findsOneWidget);

        await _tapSubmit(tester);

        expect(itemService.created, hasLength(1));
        expect(
          itemService.created.first.weight,
          isNull,
          reason: 'Blank weight must store null, not the typical weight',
        );
      },
    );

    testWidgets(
      'weight entered as decimal is stored correctly',
      (tester) async {
        final itemService = _FakeItemService();
        await tester.pumpWidget(_buildScreen(itemService: itemService));

        await _fillRequiredFields(tester);

        final weightFinder = find.byKey(const Key('field_weight'));
        await tester.ensureVisible(weightFinder);
        await tester.enterText(weightFinder, '1.5');
        await tester.pump();

        await _tapSubmit(tester);

        expect(itemService.created, hasLength(1));
        expect(itemService.created.first.weight, equals(1.5));
      },
    );

    // -----------------------------------------------------------------------
    // 4. Each of the 7 categories produces a valid document
    // -----------------------------------------------------------------------

    for (final category in ItemCategory.values) {
      testWidgets(
        'category ${category.value} produces a valid item document',
        (tester) async {
          final itemService = _FakeItemService();
          await tester.pumpWidget(_buildScreen(itemService: itemService));

          await _fillRequiredFields(
            tester,
            name: 'Test item for ${category.label}',
            category: category,
            condition: ItemCondition.good,
          );

          await _tapSubmit(tester);

          expect(
            itemService.created,
            hasLength(1),
            reason: 'Expected one item created for ${category.value}',
          );

          final item = itemService.created.first;
          expect(item.category, equals(category));
          expect(item.status, equals('active'));
          expect(item.ownerId, equals('uid-test'));

          // Verify the stored value is a valid WBS 3.6 schema string
          const validValues = {
            'clothing',
            'books',
            'kitchenware',
            'household',
            'electronics',
            'furniture',
            'other',
          };
          expect(
            validValues.contains(item.category.value),
            isTrue,
            reason: '${item.category.value} must be a valid WBS 3.6 schema value',
          );
        },
      );
    }

    // -----------------------------------------------------------------------
    // Additional: status is always 'active' on creation
    // -----------------------------------------------------------------------

    testWidgets('status is always active on creation', (tester) async {
      final itemService = _FakeItemService();
      await tester.pumpWidget(_buildScreen(itemService: itemService));

      await _fillRequiredFields(tester);
      await _tapSubmit(tester);

      expect(itemService.created.first.status, equals('active'));
    });

    // -----------------------------------------------------------------------
    // Additional: all 4 conditions are selectable and stored correctly
    // -----------------------------------------------------------------------

    for (final condition in ItemCondition.values) {
      testWidgets(
        'condition ${condition.value} is selectable and stored',
        (tester) async {
          final itemService = _FakeItemService();
          await tester.pumpWidget(_buildScreen(itemService: itemService));

          await _fillRequiredFields(tester, condition: condition);
          await _tapSubmit(tester);

          expect(itemService.created, hasLength(1));
          expect(itemService.created.first.condition, equals(condition));
        },
      );
    }
  });
}
