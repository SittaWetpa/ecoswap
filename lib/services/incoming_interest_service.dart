/// Incoming Interest Service — F18 (Anonymous Interest) data source.
///
/// Builds the map of candidates who have already swiped right on the current
/// user, keyed by the candidate's uid. Each entry names the current user's
/// item the candidate declared they want, so the Discover deck can render the
/// "Wants your {item}" badge (see [IncomingInterest]).
///
/// A candidate appears here only while interest is one-sided: once the current
/// user swipes back and a `/matches/` doc is created, the candidate is no
/// longer surfaced as incoming interest (they drop out of the feed because the
/// current user has now swiped them — see `FeedService`).
///
/// All Firestore I/O is injectable so unit tests run without a real project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ecoswap/models/incoming_interest.dart';

// ---------------------------------------------------------------------------
// Injectable typedefs
// ---------------------------------------------------------------------------

/// Returns `{ swiperId: desiredItemId }` for every right-swipe whose
/// `targetUserId` is [uid]. The `desiredItemId` references an item owned by
/// [uid] (the item the swiper wants).
typedef IncomingRightSwipesFetcher =
    Future<Map<String, String>> Function(String uid);

/// Resolves a set of item IDs to their display names: `{ itemId: name }`.
/// Missing items are simply absent from the returned map.
typedef ItemNamesResolver =
    Future<Map<String, String>> Function(Iterable<String> itemIds);

// ---------------------------------------------------------------------------
// IncomingInterestService
// ---------------------------------------------------------------------------

class IncomingInterestService {
  final IncomingRightSwipesFetcher _fetchIncoming;
  final ItemNamesResolver _resolveNames;

  IncomingInterestService({
    IncomingRightSwipesFetcher? incomingRightSwipesFetcher,
    ItemNamesResolver? itemNamesResolver,
  }) : _fetchIncoming = incomingRightSwipesFetcher ?? _defaultIncomingFetcher,
       _resolveNames = itemNamesResolver ?? _defaultNamesResolver;

  /// Returns `{ swiperId: IncomingInterest }` for the current user [uid].
  ///
  /// Candidates whose declared item can no longer be resolved to a name (e.g.
  /// the item was deleted) are omitted — there is nothing to label the badge
  /// with, so the card renders normally.
  Future<Map<String, IncomingInterest>> interestMapForUser(String uid) async {
    final incoming = await _fetchIncoming(uid);
    if (incoming.isEmpty) return const {};

    final names = await _resolveNames(incoming.values.toSet());

    final result = <String, IncomingInterest>{};
    incoming.forEach((swiperId, itemId) {
      final name = names[itemId];
      if (name == null || name.isEmpty) return;
      result[swiperId] = IncomingInterest(itemId: itemId, itemName: name);
    });
    return result;
  }

  // -------------------------------------------------------------------------
  // Default live implementations
  // -------------------------------------------------------------------------

  static Future<Map<String, String>> _defaultIncomingFetcher(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('swipes')
        .where('targetUserId', isEqualTo: uid)
        .where('direction', isEqualTo: 'right')
        .get();

    final map = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final swiperId = data['swiperId'] as String? ?? '';
      final itemId = data['desiredItemId'] as String? ?? '';
      if (swiperId.isEmpty || itemId.isEmpty) continue;
      // Last write wins if a swiper somehow has multiple right-swipe docs.
      map[swiperId] = itemId;
    }
    return map;
  }

  static Future<Map<String, String>> _defaultNamesResolver(
    Iterable<String> itemIds,
  ) async {
    final db = FirebaseFirestore.instance;
    final ids = itemIds.toList();
    final snaps = await Future.wait(
      ids.map((id) => db.collection('items').doc(id).get()),
    );

    final names = <String, String>{};
    for (final snap in snaps) {
      if (!snap.exists) continue;
      final name = snap.data()?['name'] as String? ?? '';
      if (name.isNotEmpty) names[snap.id] = name;
    }
    return names;
  }
}
