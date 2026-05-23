/// Feed Query Service — WBS 7.2
///
/// Returns the ordered list of candidate users for the swipe deck, given
/// the current user and the selected [ProximityBucket] filter.
///
/// Filters applied (in order):
///   1. Exclude self
///   2. Exclude already-swiped users
///   3. Exclude users whose proximity bucket exceeds [maxBucket]
///   4. Exclude users with zero active items
///   5. Sort by proximity bucket (closest first)
///
/// All Firestore operations are injectable via constructor parameters so tests
/// can run without a real Firebase project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/services/proximity_service.dart';

// ---------------------------------------------------------------------------
// Typedefs for injectable Firestore operations
// ---------------------------------------------------------------------------

/// Fetches all user documents from Firestore, returning a list of [User]s.
typedef UsersFetcher = Future<List<User>> Function();

/// Fetches the set of user IDs that [swiperId] has already swiped on.
typedef SwipedIdsFetcher = Future<Set<String>> Function(String swiperId);

/// Returns true if [uid] has at least one item with status 'active'.
typedef ActiveItemChecker = Future<bool> Function(String uid);

// ---------------------------------------------------------------------------
// FeedService
// ---------------------------------------------------------------------------

/// Service for WBS 7.2 — Feed Query.
///
/// Construct with the default (live Firestore) dependencies, or inject fakes
/// for unit tests:
///
/// ```dart
/// final service = FeedService(
///   proximityService: ProximityService.withTable(table),
///   usersFetcher: () async => fakeUsers,
///   swipedIdsFetcher: (id) async => {'uid-swiped'},
///   activeItemChecker: (uid) async => uid != 'no-items-uid',
/// );
/// ```
class FeedService {
  final ProximityService _proximityService;
  final UsersFetcher _fetchUsers;
  final SwipedIdsFetcher _fetchSwipedIds;
  final ActiveItemChecker _checkActiveItems;

  FeedService({
    required ProximityService proximityService,
    UsersFetcher? usersFetcher,
    SwipedIdsFetcher? swipedIdsFetcher,
    ActiveItemChecker? activeItemChecker,
  }) : _proximityService = proximityService,
       _fetchUsers = usersFetcher ?? _defaultUsersFetcher(),
       _fetchSwipedIds = swipedIdsFetcher ?? _defaultSwipedIdsFetcher(),
       _checkActiveItems = activeItemChecker ?? _defaultActiveItemChecker();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Returns candidate users for [me]'s swipe deck, filtered and sorted.
  ///
  /// [maxBucket] is the maximum proximity bucket to include. Users whose
  /// computed bucket is strictly greater than [maxBucket] are excluded.
  ///
  /// Result is sorted by proximity: closest users appear first.
  Future<List<User>> candidatesForUser(
    User me,
    ProximityBucket maxBucket,
  ) async {
    final swipedIds = await _fetchSwipedIds(me.uid);
    final allUsers = await _fetchUsers();

    // Step 1–3: filter (proximity check before active-items to reduce DB hits)
    final proximityFiltered = allUsers
        .where((u) => u.uid != me.uid)
        .where((u) => !swipedIds.contains(u.uid))
        .where(
          (u) =>
              _proximityService.bucketFor(me, u).index <= maxBucket.index,
        )
        .toList();

    // Step 4: async filter — exclude users with zero active items.
    // Checked after proximity filter to minimise the number of Firestore reads.
    final withItems = <User>[];
    for (final u in proximityFiltered) {
      if (await _checkActiveItems(u.uid)) {
        withItems.add(u);
      }
    }

    // Step 5: sort by bucket precedence (closer first).
    withItems.sort(
      (a, b) => _proximityService
          .bucketFor(me, a)
          .index
          .compareTo(_proximityService.bucketFor(me, b).index),
    );

    return withItems;
  }

  // -------------------------------------------------------------------------
  // Private helpers — these are used as defaults when no overrides are given
  // -------------------------------------------------------------------------

  /// Live Firestore users fetcher.
  static UsersFetcher _defaultUsersFetcher() {
    return () async {
      final snap =
          await FirebaseFirestore.instance.collection('users').get();
      return snap.docs
          .map((doc) => User.fromJson(doc.data(), uid: doc.id))
          .toList();
    };
  }

  /// Live Firestore swiped-IDs fetcher.
  static SwipedIdsFetcher _defaultSwipedIdsFetcher() {
    return (String swiperId) async {
      final snap = await FirebaseFirestore.instance
          .collection('swipes')
          .where('swiperId', isEqualTo: swiperId)
          .get();
      return snap.docs
          .map((doc) => doc.data()['targetUserId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    };
  }

  /// Live Firestore active-item checker.
  static ActiveItemChecker _defaultActiveItemChecker() {
    return (String uid) async {
      final snap = await FirebaseFirestore.instance
          .collection('items')
          .where('ownerId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    };
  }
}
