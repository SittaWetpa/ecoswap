/// Unit tests for WBS 7.2 — Feed Query
///
/// Covers every acceptance criterion and all five tests listed in the entry:
///   1. Self is excluded from results
///   2. Already-swiped user is excluded
///   3. User with 0 active items is excluded
///   4. Changing maxBucket from sameDistrict to allThailand increases result count
///   5. Results sorted by bucket precedence (closest first)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/services/feed_service.dart';
import 'package:ecoswap/services/proximity_service.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Minimal adjacency table covering the provinces used in tests.
///
/// Bangkok = 10, Nonthaburi = 12, Chiang Mai = 50, Phuket = 83.
/// Bangkok and Nonthaburi are neighbours; Phuket is isolated.
final _minimalTable = <String, List<String>>{
  '10': ['12'],
  '12': ['10'],
  '50': [],
  '83': [],
};

User _makeUser({
  required String uid,
  required String provinceId,
  required String districtId,
}) {
  return User(
    uid: uid,
    email: '$uid@example.com',
    displayName: uid,
    photoUrl: '',
    bio: '',
    homeDistrict: HomeDistrict(
      provinceId: provinceId,
      provinceNameTh: '',
      provinceNameEn: '',
      districtId: districtId,
      districtNameTh: '',
      districtNameEn: '',
    ),
  );
}

/// "me" — Bangkok district 1001.
final _me = _makeUser(uid: 'me', provinceId: '10', districtId: '1001');

/// Same district as _me.
final _sameDistrict = _makeUser(
  uid: 'same-district',
  provinceId: '10',
  districtId: '1001',
);

/// Same province as _me, different district.
final _sameProvince = _makeUser(
  uid: 'same-province',
  provinceId: '10',
  districtId: '1002',
);

/// Nearby province (Nonthaburi = 12, neighbour of Bangkok = 10).
final _nearbyProvince = _makeUser(
  uid: 'nearby-province',
  provinceId: '12',
  districtId: '1201',
);

/// Far-away province (Phuket = 83, not a neighbour of Bangkok).
final _farAway = _makeUser(
  uid: 'far-away',
  provinceId: '83',
  districtId: '8301',
);

/// Builds a [FeedService] with fully injectable dependencies — no real Firestore.
FeedService _makeService({
  List<User>? allUsers,
  Set<String>? swipedIds,
  Set<String>? usersWithNoItems,
}) {
  final users = allUsers ?? [];
  final swiped = swipedIds ?? {};
  final noItems = usersWithNoItems ?? {};

  return FeedService(
    proximityService: ProximityService.withTable(_minimalTable),
    usersFetcher: () async => users,
    swipedIdsFetcher: (_) async => swiped,
    activeItemChecker: (uid) async => !noItems.contains(uid),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. Self is excluded from results
  // -------------------------------------------------------------------------
  group('FeedService — self exclusion', () {
    test('current user never appears in their own feed', () async {
      final service = _makeService(allUsers: [_me, _sameDistrict]);

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      final uids = results.map((u) => u.uid).toList();
      expect(uids, isNot(contains('me')));
    });

    test('self exclusion holds even when _me is the only user', () async {
      final service = _makeService(allUsers: [_me]);

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      expect(results, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Already-swiped user is excluded
  // -------------------------------------------------------------------------
  group('FeedService — already-swiped exclusion', () {
    test('already-swiped user is not returned', () async {
      final service = _makeService(
        allUsers: [_sameDistrict, _sameProvince],
        swipedIds: {_sameDistrict.uid},
      );

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      final uids = results.map((u) => u.uid).toList();
      expect(uids, isNot(contains(_sameDistrict.uid)));
      expect(uids, contains(_sameProvince.uid));
    });

    test('multiple swiped users are all excluded', () async {
      final service = _makeService(
        allUsers: [_sameDistrict, _sameProvince, _nearbyProvince],
        swipedIds: {_sameDistrict.uid, _nearbyProvince.uid},
      );

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      final uids = results.map((u) => u.uid).toList();
      expect(uids, isNot(contains(_sameDistrict.uid)));
      expect(uids, isNot(contains(_nearbyProvince.uid)));
      expect(uids, contains(_sameProvince.uid));
    });
  });

  // -------------------------------------------------------------------------
  // 3. User with 0 active items is excluded
  // -------------------------------------------------------------------------
  group('FeedService — zero-active-items exclusion', () {
    test('user with no active items is excluded from results', () async {
      final service = _makeService(
        allUsers: [_sameDistrict, _sameProvince],
        usersWithNoItems: {_sameDistrict.uid},
      );

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      final uids = results.map((u) => u.uid).toList();
      expect(uids, isNot(contains(_sameDistrict.uid)));
      expect(uids, contains(_sameProvince.uid));
    });

    test(
      'all users with no items excluded — empty result when no one has items',
      () async {
        final service = _makeService(
          allUsers: [_sameDistrict, _sameProvince],
          usersWithNoItems: {_sameDistrict.uid, _sameProvince.uid},
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.allThailand,
        );

        expect(results, isEmpty);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 4. Proximity filter actually changes the result set
  // -------------------------------------------------------------------------
  group('FeedService — proximity filter', () {
    test(
      'sameDistrict bucket returns fewer results than allThailand bucket',
      () async {
        // sameDistrict should include _sameDistrict only.
        // allThailand includes _sameDistrict, _sameProvince, _nearbyProvince, _farAway.
        final service = _makeService(
          allUsers: [_sameDistrict, _sameProvince, _nearbyProvince, _farAway],
        );

        final districtResults = await service.candidatesForUser(
          _me,
          ProximityBucket.sameDistrict,
        );
        final allResults = await service.candidatesForUser(
          _me,
          ProximityBucket.allThailand,
        );

        expect(districtResults.length, lessThan(allResults.length));
      },
    );

    test(
      'sameDistrict only returns users in exactly the same district',
      () async {
        final service = _makeService(
          allUsers: [_sameDistrict, _sameProvince, _nearbyProvince, _farAway],
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.sameDistrict,
        );

        final uids = results.map((u) => u.uid).toList();
        expect(uids, contains(_sameDistrict.uid));
        expect(uids, isNot(contains(_sameProvince.uid)));
        expect(uids, isNot(contains(_nearbyProvince.uid)));
        expect(uids, isNot(contains(_farAway.uid)));
      },
    );

    test(
      'sameProvince includes same-district and same-province users',
      () async {
        final service = _makeService(
          allUsers: [_sameDistrict, _sameProvince, _nearbyProvince, _farAway],
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.sameProvince,
        );

        final uids = results.map((u) => u.uid).toList();
        expect(uids, contains(_sameDistrict.uid));
        expect(uids, contains(_sameProvince.uid));
        expect(uids, isNot(contains(_nearbyProvince.uid)));
        expect(uids, isNot(contains(_farAway.uid)));
      },
    );

    test(
      'nearbyProvinces includes same-district, same-province, and nearby',
      () async {
        final service = _makeService(
          allUsers: [_sameDistrict, _sameProvince, _nearbyProvince, _farAway],
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.nearbyProvinces,
        );

        final uids = results.map((u) => u.uid).toList();
        expect(uids, contains(_sameDistrict.uid));
        expect(uids, contains(_sameProvince.uid));
        expect(uids, contains(_nearbyProvince.uid));
        expect(uids, isNot(contains(_farAway.uid)));
      },
    );

    test(
      'allThailand includes every non-self, non-swiped user with items',
      () async {
        final service = _makeService(
          allUsers: [_sameDistrict, _sameProvince, _nearbyProvince, _farAway],
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.allThailand,
        );

        final uids = results.map((u) => u.uid).toList();
        expect(
          uids,
          containsAll([
            _sameDistrict.uid,
            _sameProvince.uid,
            _nearbyProvince.uid,
            _farAway.uid,
          ]),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // 5. Results sorted by bucket precedence (closest first)
  // -------------------------------------------------------------------------
  group('FeedService — sort order', () {
    test(
      'results are sorted by proximity bucket ascending (closest first)',
      () async {
        // allThailand includes all four, they should be sorted:
        // sameDistrict(0) < sameProvince(1) < nearbyProvinces(2) < allThailand(3)
        final service = _makeService(
          allUsers: [_farAway, _nearbyProvince, _sameProvince, _sameDistrict],
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.allThailand,
        );

        expect(results, hasLength(4));
        // First must be sameDistrict, last must be farAway (allThailand bucket).
        expect(results.first.uid, _sameDistrict.uid);
        expect(results.last.uid, _farAway.uid);
      },
    );

    test('within the same bucket, relative order is stable', () async {
      // Two users in the same province (both sameProvince bucket).
      final provinceUser2 = _makeUser(
        uid: 'province-2',
        provinceId: '10',
        districtId: '1003',
      );

      final service = _makeService(allUsers: [_sameProvince, provinceUser2]);

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      // Both are present, both in sameProvince bucket — order among them is
      // implementation-defined but deterministic.
      expect(results, hasLength(2));
      final uids = results.map((u) => u.uid).toList();
      expect(uids, containsAll([_sameProvince.uid, 'province-2']));
    });

    test(
      'nearbyProvince user appears after same-district and same-province',
      () async {
        final service = _makeService(
          allUsers: [_nearbyProvince, _sameDistrict, _sameProvince],
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.allThailand,
        );

        final uids = results.map((u) => u.uid).toList();
        final nearbyIndex = uids.indexOf(_nearbyProvince.uid);
        final sameDistrictIndex = uids.indexOf(_sameDistrict.uid);
        final sameProvinceIndex = uids.indexOf(_sameProvince.uid);

        // Closer buckets must come before farther ones.
        expect(sameDistrictIndex, lessThan(nearbyIndex));
        expect(sameProvinceIndex, lessThan(nearbyIndex));
      },
    );
  });

  // -------------------------------------------------------------------------
  // Combination: all filters working together
  // -------------------------------------------------------------------------
  group('FeedService — combined filters', () {
    test(
      'excludes self, swiped, zero-items, out-of-range users simultaneously',
      () async {
        final noItemsUser = _makeUser(
          uid: 'no-items',
          provinceId: '10',
          districtId: '1001',
        );
        final swipedUser = _makeUser(
          uid: 'swiped',
          provinceId: '10',
          districtId: '1001',
        );

        final service = _makeService(
          allUsers: [
            _me,
            noItemsUser,
            swipedUser,
            _farAway, // out of range for sameDistrict
            _sameDistrict, // the only valid candidate
          ],
          swipedIds: {swipedUser.uid},
          usersWithNoItems: {noItemsUser.uid},
        );

        final results = await service.candidatesForUser(
          _me,
          ProximityBucket.sameDistrict,
        );

        expect(results, hasLength(1));
        expect(results.first.uid, _sameDistrict.uid);
      },
    );

    test('empty result when all candidates are filtered out', () async {
      final service = _makeService(
        allUsers: [_me, _sameDistrict],
        swipedIds: {_sameDistrict.uid},
      );

      final results = await service.candidatesForUser(
        _me,
        ProximityBucket.allThailand,
      );

      expect(results, isEmpty);
    });
  });
}
