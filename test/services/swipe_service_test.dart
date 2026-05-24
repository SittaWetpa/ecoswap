/// Unit tests for WBS 8.1 — Swipe Write to Firestore
///
/// Covers all four tests listed in the WBS entry:
///   1. recordSwipe(target, 'left') writes correct doc shape
///   2. recordSwipe(target, 'right', desiredItemId: 'item123') writes correct doc
///   3. recordSwipe(target, 'right') without desiredItemId throws ArgumentError
///   4. Rapid successive swipes produce two distinct document IDs
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/services/swipe_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _swiperId = 'user-me';
const _targetId = 'user-target';

/// Fake SwipeDocAdder that records every call made to it.
///
/// Each call receives the data map and returns a sequential fake ID
/// ('fake-id-1', 'fake-id-2', …) so tests can assert that two calls
/// produce two distinct IDs.
class _FakeAdder {
  int _callCount = 0;
  final List<Map<String, dynamic>> calls = [];

  Future<String> call(Map<String, dynamic> data) async {
    _callCount++;
    calls.add(Map<String, dynamic>.from(data));
    return 'fake-id-$_callCount';
  }
}

SwipeService _makeService(_FakeAdder adder) {
  return SwipeService(currentUserId: _swiperId, swipeDocAdder: adder.call);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SwipeService.recordSwipe()', () {
    // -----------------------------------------------------------------------
    // Test 1 — left-swipe writes correct doc shape
    // -----------------------------------------------------------------------
    test(
      'left-swipe writes direction:left and desiredItemId:empty-string',
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        final docId = await service.recordSwipe(_targetId, 'left');

        expect(docId, equals('fake-id-1'));
        expect(adder.calls.length, equals(1));

        final doc = adder.calls.first;
        expect(doc['swiperId'], equals(_swiperId));
        expect(doc['targetUserId'], equals(_targetId));
        expect(doc['direction'], equals('left'));
        // Empty string sentinel — NOT null (per WBS 8.1 locked decision).
        expect(doc['desiredItemId'], equals(''));
        // createdAt must be present (server timestamp placeholder).
        expect(doc['createdAt'], isNotNull);
        expect(doc['createdAt'], isA<FieldValue>());
        // Doc must contain exactly the 5 locked fields and nothing else.
        expect(
          doc.keys.toSet(),
          equals({
            'swiperId',
            'targetUserId',
            'direction',
            'desiredItemId',
            'createdAt',
          }),
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 2 — right-swipe with desiredItemId writes correct doc shape
    // -----------------------------------------------------------------------
    test(
      'right-swipe writes direction:right and the supplied desiredItemId',
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        final docId = await service.recordSwipe(
          _targetId,
          'right',
          desiredItemId: 'item123',
        );

        expect(docId, equals('fake-id-1'));
        expect(adder.calls.length, equals(1));

        final doc = adder.calls.first;
        expect(doc['swiperId'], equals(_swiperId));
        expect(doc['targetUserId'], equals(_targetId));
        expect(doc['direction'], equals('right'));
        expect(doc['desiredItemId'], equals('item123'));
        expect(doc['createdAt'], isNotNull);
        expect(doc['createdAt'], isA<FieldValue>());
        expect(
          doc.keys.toSet(),
          equals({
            'swiperId',
            'targetUserId',
            'direction',
            'desiredItemId',
            'createdAt',
          }),
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 3 — right-swipe without desiredItemId throws ArgumentError
    // -----------------------------------------------------------------------
    test('right-swipe without desiredItemId throws ArgumentError', () async {
      final adder = _FakeAdder();
      final service = _makeService(adder);

      await expectLater(
        () => service.recordSwipe(_targetId, 'right'),
        throwsA(isA<ArgumentError>()),
      );

      // No document must have been written.
      expect(adder.calls, isEmpty);
    });

    test(
      'right-swipe with explicit empty desiredItemId throws ArgumentError',
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        await expectLater(
          () => service.recordSwipe(_targetId, 'right', desiredItemId: ''),
          throwsA(isA<ArgumentError>()),
        );

        expect(adder.calls, isEmpty);
      },
    );

    // -----------------------------------------------------------------------
    // Test 4 — rapid successive swipes produce distinct document IDs
    // -----------------------------------------------------------------------
    test('two rapid successive left-swipes on different targets produce '
        'two distinct document IDs', () async {
      final adder = _FakeAdder();
      final service = _makeService(adder);

      // Fire both without awaiting between them to simulate rapid swipes.
      final results = await Future.wait([
        service.recordSwipe('target-a', 'left'),
        service.recordSwipe('target-b', 'left'),
      ]);

      expect(adder.calls.length, equals(2));
      // The two IDs must be distinct.
      expect(results[0], isNot(equals(results[1])));
      // Each call wrote to its respective target.
      expect(adder.calls[0]['targetUserId'], equals('target-a'));
      expect(adder.calls[1]['targetUserId'], equals('target-b'));
    });

    test('two rapid successive right-swipes on different targets produce '
        'two distinct document IDs', () async {
      final adder = _FakeAdder();
      final service = _makeService(adder);

      final results = await Future.wait([
        service.recordSwipe('target-a', 'right', desiredItemId: 'item-a1'),
        service.recordSwipe('target-b', 'right', desiredItemId: 'item-b1'),
      ]);

      expect(adder.calls.length, equals(2));
      expect(results[0], isNot(equals(results[1])));
      expect(adder.calls[0]['desiredItemId'], equals('item-a1'));
      expect(adder.calls[1]['desiredItemId'], equals('item-b1'));
    });

    // -----------------------------------------------------------------------
    // Additional — left-swipe normalises a passed desiredItemId to ''
    // -----------------------------------------------------------------------
    test('left-swipe always stores desiredItemId as empty string '
        'even if a non-empty value is accidentally passed', () async {
      final adder = _FakeAdder();
      final service = _makeService(adder);

      await service.recordSwipe(
        _targetId,
        'left',
        desiredItemId: 'stale-item-id',
      );

      expect(adder.calls.first['desiredItemId'], equals(''));
    });
  });
}
