/// Widget tests for DiscoverTab — WBS 7.4 integration wrapper.
///
/// Verifies that DiscoverTab:
///   1. Shows a loading indicator while the feed is loading.
///   2. Shows DiscoverScreen after a successful feed load.
///   3. Re-calls FeedService.candidatesForUser when the proximity bucket changes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/discover/discover_refresh_signal.dart';
import 'package:ecoswap/screens/discover/discover_screen.dart';
import 'package:ecoswap/screens/discover/discover_tab.dart';
import 'package:ecoswap/services/feed_service.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/proximity_service.dart';
import 'package:ecoswap/widgets/proximity_filter_sheet.dart';

// ---------------------------------------------------------------------------
// Test helpers — shared fake user / item
// ---------------------------------------------------------------------------

final _fakeMe = User(
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

final _fakeCandidate = User(
  uid: 'candidate-1',
  email: 'c1@example.com',
  displayName: 'Candidate One',
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

// ---------------------------------------------------------------------------
// Fake FeedService helpers
// ---------------------------------------------------------------------------

/// Builds a [FeedService] backed by injectable closures.
FeedService _makeFeedService({List<User> candidates = const []}) {
  return FeedService(
    proximityService: ProximityService.withTable(const {}),
    usersFetcher: () async => candidates,
    swipedIdsFetcher: (_) async => {},
    activeItemChecker: (_) async => true,
  );
}

/// A [FeedService] whose [candidatesForUser] never completes.
///
/// Built by replacing the internal [UsersFetcher] with a Completer that is
/// never resolved.
class _BlockingFeedService extends FeedService {
  _BlockingFeedService()
    : super(
        proximityService: ProximityService.withTable(const {}),
        // usersFetcher returns a Future that never resolves.
        usersFetcher: () => Completer<List<User>>().future,
        swipedIdsFetcher: (_) async => {},
        activeItemChecker: (_) async => true,
      );
}

/// A [FeedService] that counts how many times [candidatesForUser] is called.
///
/// Uses a shared [callCount] list (single-element) to allow mutation from
/// within the closure.
class _CountingFeedService extends FeedService {
  final List<int> callCount;
  final List<User> _candidates;

  _CountingFeedService({
    required this.callCount,
    required List<User> candidates,
  }) : _candidates = candidates,
       super(
         proximityService: ProximityService.withTable(const {}),
         usersFetcher: () async => candidates,
         swipedIdsFetcher: (_) async => {},
         activeItemChecker: (_) async => true,
       );

  @override
  Future<List<User>> candidatesForUser(
    User me,
    ProximityBucket maxBucket,
  ) async {
    callCount[0]++;
    return _candidates;
  }
}

// ---------------------------------------------------------------------------
// Fake ItemService helper
// ---------------------------------------------------------------------------

ItemService _makeItemService({List<Item> items = const []}) {
  return ItemService(activeItemsStreamOverride: (_) => Stream.value(items));
}

// ---------------------------------------------------------------------------
// Widget wrapper
// ---------------------------------------------------------------------------

/// Wraps [DiscoverTab] in a [MaterialApp] with [SharedPreferences] mocked to
/// an empty state so persistence reads return the default bucket.
Widget _buildTab({
  FeedService? feedService,
  ItemService? itemService,
  CurrentUserFetcher? currentUserFetcher,
}) {
  return MaterialApp(
    home: DiscoverTab(
      feedServiceOverride: feedService,
      itemServiceOverride: itemService,
      currentUserFetcherOverride: currentUserFetcher,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    // Reset SharedPreferences to default (empty) state before each test so
    // the persisted bucket doesn't bleed between tests.
    SharedPreferences.setMockInitialValues({});
  });

  // ── Test 1: shows_loading_indicator ──────────────────────────────────────

  group('DiscoverTab — shows_loading_indicator', () {
    testWidgets('CircularProgressIndicator is visible while feed is loading', (
      tester,
    ) async {
      // Use a _BlockingFeedService so candidatesForUser never resolves.
      // The currentUserFetcher must return a user so _loadFeed proceeds past
      // the uid-null check.
      await tester.pumpWidget(
        _buildTab(
          feedService: _BlockingFeedService(),
          itemService: _makeItemService(),
          currentUserFetcher: () async => _fakeMe,
        ),
      );

      // pump() without settle — the async _loadFeed is in flight.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ── Test 2: shows_candidates_after_load ──────────────────────────────────

  group('DiscoverTab — shows_candidates_after_load', () {
    testWidgets(
      'DiscoverScreen is present in the widget tree after feed loads',
      (tester) async {
        await tester.pumpWidget(
          _buildTab(
            feedService: _makeFeedService(candidates: [_fakeCandidate]),
            itemService: _makeItemService(),
            currentUserFetcher: () async => _fakeMe,
          ),
        );

        // Allow all async work (SharedPreferences + feed loading) to complete.
        await tester.pumpAndSettle();

        expect(find.byType(DiscoverScreen), findsOneWidget);
        // Loading indicator should be gone.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  // ── Test 3: bucket_change_triggers_reload ────────────────────────────────

  group('DiscoverTab — bucket_change_triggers_reload', () {
    testWidgets(
      'candidatesForUser is called a second time when proximity bucket changes',
      (tester) async {
        final callCount = [0];
        final countingService = _CountingFeedService(
          callCount: callCount,
          candidates: [_fakeCandidate],
        );

        await tester.pumpWidget(
          _buildTab(
            feedService: countingService,
            itemService: _makeItemService(),
            currentUserFetcher: () async => _fakeMe,
          ),
        );

        // Wait for the initial feed load to complete.
        await tester.pumpAndSettle();
        expect(callCount[0], 1);

        // Tap the ProximityPill to open the filter sheet.
        expect(find.byType(ProximityPill), findsOneWidget);
        await tester.tap(find.byType(ProximityPill));
        await tester.pumpAndSettle();

        // The ProximityFilterSheet should now be showing 4 options.
        // Tap "All Thailand" to change the bucket.
        expect(find.text('All Thailand'), findsOneWidget);
        await tester.tap(find.text('All Thailand'));
        await tester.pumpAndSettle();

        // candidatesForUser should have been called a second time.
        expect(callCount[0], 2);
      },
    );
  });

  // ── Test 4: refresh_tick_triggers_reload (post-trade re-discovery, #3) ────

  group('DiscoverTab — refresh_tick_triggers_reload', () {
    testWidgets(
      'candidatesForUser is re-run when discoverRefreshTick bumps (tab reselect)',
      (tester) async {
        final callCount = [0];
        final countingService = _CountingFeedService(
          callCount: callCount,
          candidates: [_fakeCandidate],
        );

        await tester.pumpWidget(
          _buildTab(
            feedService: countingService,
            itemService: _makeItemService(),
            currentUserFetcher: () async => _fakeMe,
          ),
        );

        // Initial load.
        await tester.pumpAndSettle();
        expect(callCount[0], 1);

        // Simulate the shell re-selecting the Discover tab.
        discoverRefreshTick.value++;
        await tester.pumpAndSettle();

        // The deck silently re-queried — no loading spinner flashed, but the
        // feed was fetched again so newly-eligible users can surface.
        expect(callCount[0], 2);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(DiscoverScreen), findsOneWidget);
      },
    );
  });
}
