/// Unit tests for [IncomingInterestService] — F18 (Anonymous Interest).
///
/// All Firestore I/O is injected, so these tests run without a real project.
library;

import 'package:ecoswap/services/incoming_interest_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IncomingInterestService.interestMapForUser', () {
    test('maps each incoming right-swipe to its declared item name', () async {
      final service = IncomingInterestService(
        incomingRightSwipesFetcher: (uid) async {
          expect(uid, 'me');
          return {'swiper-a': 'item-1', 'swiper-b': 'item-2'};
        },
        itemNamesResolver: (ids) async {
          expect(ids.toSet(), {'item-1', 'item-2'});
          return {'item-1': 'Cow', 'item-2': 'Desk lamp'};
        },
      );

      final map = await service.interestMapForUser('me');

      expect(map.keys.toSet(), {'swiper-a', 'swiper-b'});
      expect(map['swiper-a']!.itemId, 'item-1');
      expect(map['swiper-a']!.itemName, 'Cow');
      expect(map['swiper-b']!.itemName, 'Desk lamp');
    });

    test('returns empty map when there is no incoming interest', () async {
      var resolverCalled = false;
      final service = IncomingInterestService(
        incomingRightSwipesFetcher: (_) async => {},
        itemNamesResolver: (_) async {
          resolverCalled = true;
          return {};
        },
      );

      final map = await service.interestMapForUser('me');

      expect(map, isEmpty);
      // Short-circuits — no point resolving names for zero items.
      expect(resolverCalled, isFalse);
    });

    test('omits candidates whose item name cannot be resolved', () async {
      final service = IncomingInterestService(
        incomingRightSwipesFetcher: (_) async => {
          'swiper-a': 'item-1',
          'swiper-deleted': 'item-gone',
        },
        // item-gone has no name (e.g. deleted item) — absent from the result.
        itemNamesResolver: (_) async => {'item-1': 'Cow'},
      );

      final map = await service.interestMapForUser('me');

      expect(map.keys.toSet(), {'swiper-a'});
      expect(map.containsKey('swiper-deleted'), isFalse);
    });
  });
}
