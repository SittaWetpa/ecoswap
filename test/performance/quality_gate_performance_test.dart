/// Performance quality-gate instrumentation (WBS §8.2 — Performance gate).
///
/// The Discover deck refresh added on this branch (#3) re-queries the feed on
/// every Discover tab selection. This test QUANTIFIES that cost so the
/// Performance Analyst has a concrete number rather than a hunch:
///
///   Per refresh, in production, the live FeedService performs:
///     • 1 read of the whole `users` collection      (UsersFetcher)
///     • 1 read of the swiper's `swipes`              (SwipedIdsFetcher)
///     • 1 active-item query per surviving candidate  (ActiveItemChecker)
///   …and DiscoverTab then fetches active items + the interest map per
///   candidate. There is no caching/dedup between refreshes.
///
/// This test counts the feed-load multiplier across repeated tab selections to
/// confirm the linear (uncached) cost.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/discover/discover_refresh_signal.dart';
import 'package:ecoswap/screens/discover/discover_tab.dart';
import 'package:ecoswap/services/feed_service.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/proximity_service.dart';

final _me = User(
  uid: 'me',
  email: 'me@example.com',
  displayName: 'Me',
  photoUrl: '',
  bio: '',
  homeDistrict: const HomeDistrict(
    provinceId: '10',
    provinceNameTh: 'กรุงเทพมหานคร',
    provinceNameEn: 'Bangkok',
    districtId: '1001',
    districtNameTh: 'บางมด',
    districtNameEn: 'Bang Mod',
  ),
);

final _candidate = User(
  uid: 'c1',
  email: 'c1@example.com',
  displayName: 'Candidate',
  photoUrl: '',
  bio: '',
  homeDistrict: _me.homeDistrict,
);

/// Counts how many times the feed is queried.
class _CountingFeedService extends FeedService {
  final List<int> feedCalls;
  final List<User> _candidates;

  _CountingFeedService(this.feedCalls, this._candidates)
    : super(
        proximityService: ProximityService.withTable(const {}),
        usersFetcher: () async => _candidates,
        swipedIdsFetcher: (_) async => {},
        activeItemChecker: (_) async => true,
      );

  @override
  Future<List<User>> candidatesForUser(
    User me,
    ProximityBucket maxBucket,
  ) async {
    feedCalls[0]++;
    return _candidates;
  }
}

/// Counts how many times per-candidate active items are fetched.
ItemService _countingItemService(List<int> itemFetches) {
  return ItemService(
    activeItemsStreamOverride: (_) {
      itemFetches[0]++;
      return Stream.value(const <Item>[]);
    },
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Discover refresh cost is linear and uncached — N reselects ⇒ N+1 feed loads',
    (tester) async {
      final feedCalls = [0];
      final itemFetches = [0];

      await tester.pumpWidget(
        MaterialApp(
          home: DiscoverTab(
            feedServiceOverride: _CountingFeedService(feedCalls, [_candidate]),
            itemServiceOverride: _countingItemService(itemFetches),
            currentUserFetcherOverride: () async => _me,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial load.
      expect(feedCalls[0], 1, reason: 'initState performs one feed load');
      expect(itemFetches[0], 1, reason: 'one active-items fetch per candidate');

      // Re-select the Discover tab 5 times (the shell bumps the tick each time).
      for (var i = 0; i < 5; i++) {
        discoverRefreshTick.value++;
        await tester.pumpAndSettle();
      }

      // Cost is linear: 1 initial + 5 refreshes = 6 full feed loads, each with
      // its own per-candidate item fetch. No caching between selections.
      expect(
        feedCalls[0],
        6,
        reason: 'every reselect triggers a full feed load',
      );
      expect(itemFetches[0], 6, reason: 'item fetch repeats every refresh');
    },
  );
}
