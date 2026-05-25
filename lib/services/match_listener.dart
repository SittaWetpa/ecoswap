/// Match Listener — WBS 8.4
///
/// Global Firestore listener that surfaces new matches to the current user
/// exactly once per matchId.  Seen matchIds are persisted in
/// `shared_preferences` so the celebration screen is never shown again on a
/// subsequent foreground.
///
/// Design decisions (per WBS 8.4):
/// - Listens to `/matches/` where `participants` array-contains the current uid.
/// - Resolves each new match doc into a [MatchProposal] by fetching the two
///   item docs and the counterparty user doc.
/// - Emits via a [StreamController<MatchProposal>] consumed by the UI layer.
/// - All Firestore/SharedPreferences interactions are injectable for testing.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/match.dart' as match_model;
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/match/match_celebration_screen.dart'
    show MatchProposal;

// ---------------------------------------------------------------------------
// Injectable typedefs
// ---------------------------------------------------------------------------

/// Returns the IDs of all matchIds already seen by this device.
typedef SeenMatchesLoader = Future<Set<String>> Function();

/// Marks a matchId as seen so the celebration is not repeated.
typedef SeenMatchMarker = Future<void> Function(String matchId);

/// Fetches a single document from any Firestore collection.
typedef DocFetcher =
    Future<Map<String, dynamic>?> Function(String collection, String docId);

/// Produces the real matches stream for the authenticated user.
typedef MatchesStreamFactory =
    Stream<List<match_model.Match>> Function(String uid);

// ---------------------------------------------------------------------------
// SharedPreferences helpers (production implementations)
// ---------------------------------------------------------------------------

const _kPrefsKey = 'ecoswap_seen_matches';

Future<Set<String>> _defaultLoader() async {
  final prefs = await SharedPreferences.getInstance();
  final list = prefs.getStringList(_kPrefsKey) ?? [];
  return Set<String>.from(list);
}

Future<void> _defaultMarker(String matchId) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getStringList(_kPrefsKey) ?? [];
  if (!current.contains(matchId)) {
    current.add(matchId);
    await prefs.setStringList(_kPrefsKey, current);
  }
}

// ---------------------------------------------------------------------------
// Firestore helpers (production implementations)
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>?> _defaultDocFetcher(
  String collection,
  String docId,
) async {
  final snap = await FirebaseFirestore.instance
      .collection(collection)
      .doc(docId)
      .get();
  return snap.data();
}

Stream<List<match_model.Match>> _defaultMatchesStreamFactory(String uid) {
  return FirebaseFirestore.instance
      .collection('matches')
      .where('participants', arrayContains: uid)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => match_model.Match.fromJson(doc.data(), id: doc.id))
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// MatchListener
// ---------------------------------------------------------------------------

/// Listens for new matches and exposes them as a stream of [MatchProposal]s.
///
/// Usage (production):
/// ```dart
/// final listener = MatchListener(currentUserId: uid);
/// listener.proposals.listen((proposal) {
///   // Show MatchCelebrationScreen.
/// });
/// listener.dispose(); // call in dispose()
/// ```
///
/// Usage (tests):
/// ```dart
/// final controller = StreamController<List<Match>>();
/// final listener = MatchListener(
///   currentUserId: 'uid-me',
///   matchesStreamFactory: (_) => controller.stream,
///   seenLoader: () async => {},
///   seenMarker: (id) async {},
///   docFetcher: (col, id) async => fakeData[col]?[id],
/// );
/// ```
class MatchListener {
  final String _currentUserId;
  final SeenMatchesLoader _seenLoader;
  final SeenMatchMarker _seenMarker;
  final DocFetcher _docFetcher;
  final MatchesStreamFactory _streamFactory;

  final _controller = StreamController<MatchProposal>.broadcast();

  StreamSubscription<List<match_model.Match>>? _subscription;

  MatchListener({
    required String currentUserId,
    SeenMatchesLoader? seenLoader,
    SeenMatchMarker? seenMarker,
    DocFetcher? docFetcher,
    MatchesStreamFactory? matchesStreamFactory,
  }) : _currentUserId = currentUserId,
       _seenLoader = seenLoader ?? _defaultLoader,
       _seenMarker = seenMarker ?? _defaultMarker,
       _docFetcher = docFetcher ?? _defaultDocFetcher,
       _streamFactory = matchesStreamFactory ?? _defaultMatchesStreamFactory;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Stream of new (never-seen) [MatchProposal]s.
  Stream<MatchProposal> get proposals => _controller.stream;

  /// Start listening.  Safe to call multiple times — re-entrant calls are
  /// ignored.
  void start() {
    if (_subscription != null) return;
    _subscription = _streamFactory(_currentUserId).listen(_onMatchesUpdate);
  }

  /// Cancel the Firestore listener and close the proposals stream.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _onMatchesUpdate(List<match_model.Match> matches) async {
    final seen = await _seenLoader();

    for (final match in matches) {
      if (seen.contains(match.id)) continue;

      final proposal = await _resolveProposal(match);
      if (proposal == null) continue;

      // Mark seen BEFORE emitting so rapid double-calls cannot double-show.
      await _seenMarker(match.id);
      _controller.add(proposal);
    }
  }

  /// Resolves a match doc to a [MatchProposal] by fetching item + user docs.
  ///
  /// Returns null if any required document is missing (defensive).
  Future<MatchProposal?> _resolveProposal(match_model.Match match) async {
    final isUserA = match.userAId == _currentUserId;

    // myItemId is the item THIS user is offering (what the OTHER person wants).
    // theirItemId is the item THIS user receives (what THIS user wanted).
    final myItemId = isUserA ? match.userBWantsItemId : match.userAWantsItemId;
    final theirItemId = isUserA
        ? match.userAWantsItemId
        : match.userBWantsItemId;
    final otherUserId = isUserA ? match.userBId : match.userAId;

    // Fetch in parallel.
    final results = await Future.wait([
      _docFetcher('items', myItemId),
      _docFetcher('items', theirItemId),
      _docFetcher('users', otherUserId),
    ]);

    final myItemData = results[0];
    final theirItemData = results[1];
    final otherUserData = results[2];

    if (myItemData == null || theirItemData == null || otherUserData == null) {
      return null;
    }

    final myItem = Item.fromJson(myItemData, id: myItemId);
    final theirItem = Item.fromJson(theirItemData, id: theirItemId);
    final otherUser = User.fromJson(otherUserData, uid: otherUserId);

    return MatchProposal(
      matchId: match.id,
      otherUser: otherUser,
      myItem: myItem,
      theirItem: theirItem,
    );
  }
}
