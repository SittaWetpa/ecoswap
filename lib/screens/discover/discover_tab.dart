/// Discover Tab — WBS 7.4 integration wrapper
///
/// Wraps [DiscoverScreen] with real Firestore data loading.
///
/// Responsibilities:
///   - Reads the persisted [ProximityBucket] from [SharedPreferences] on init.
///   - Calls [FeedService.candidatesForUser] to populate the swipe deck.
///   - Loads active items for each candidate via [ItemService.activeItemsForUser].
///   - Re-triggers [_loadFeed] whenever the proximity filter changes.
///
/// All Firebase and service calls are injectable via constructor parameters so
/// widget tests can run without a real Firebase project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/models/incoming_interest.dart';
import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart' as app;
import 'package:ecoswap/providers/auth_provider.dart';
import 'package:ecoswap/screens/discover/discover_refresh_signal.dart';
import 'package:ecoswap/screens/discover/discover_screen.dart';
import 'package:ecoswap/screens/discover/user_detail_screen.dart';
import 'package:ecoswap/services/feed_service.dart';
import 'package:ecoswap/services/incoming_interest_service.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/proximity_service.dart';
import 'package:ecoswap/services/swipe_service.dart';
import 'package:ecoswap/widgets/item_picker_modal.dart';
import 'package:ecoswap/widgets/proximity_filter_sheet.dart';

// ---------------------------------------------------------------------------
// Typedefs for injectable dependencies
// ---------------------------------------------------------------------------

/// Fetches the current user's [app.User] document.
///
/// Returns `null` when the user is not signed in or the document doesn't exist.
/// Inject a fake in tests to avoid real Firebase calls.
typedef CurrentUserFetcher = Future<app.User?> Function();

// ---------------------------------------------------------------------------
// Default live implementations
// ---------------------------------------------------------------------------

/// Live [CurrentUserFetcher] — reads the current uid from [AuthProvider]
/// (per WBS 4.4 acceptance: only the provider may read [FirebaseAuth] directly)
/// then loads the Firestore `/users/{uid}` document.
CurrentUserFetcher _defaultCurrentUserFetcher(AuthProvider authProvider) {
  return () async {
    final uid = authProvider.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return app.User.fromJson(doc.data()!, uid: doc.id);
  };
}

// ---------------------------------------------------------------------------
// DiscoverTab
// ---------------------------------------------------------------------------

/// Stateful wrapper that owns data loading for [DiscoverScreen].
///
/// Pass [feedServiceOverride], [itemServiceOverride], and
/// [currentUserFetcherOverride] in tests to avoid real Firebase calls.
class DiscoverTab extends StatefulWidget {
  /// Override the [FeedService] used to fetch candidates. Tests only.
  final FeedService? feedServiceOverride;

  /// Override the [ItemService] used to fetch active items. Tests only.
  final ItemService? itemServiceOverride;

  /// Override the function that resolves the current [app.User]. Tests only.
  ///
  /// When omitted the live Firebase implementation is used.
  final CurrentUserFetcher? currentUserFetcherOverride;

  /// Override the [IncomingInterestService] used to build the F18 interest
  /// map. Tests only.
  final IncomingInterestService? interestServiceOverride;

  const DiscoverTab({
    super.key,
    this.feedServiceOverride,
    this.itemServiceOverride,
    this.currentUserFetcherOverride,
    this.interestServiceOverride,
  });

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  List<app.User> _candidates = [];
  Map<String, List<Item>> _itemsByUser = {};
  Map<String, IncomingInterest> _interestMap = {};
  bool _isLoading = true;
  String? _error;
  ProximityBucket _bucket = ProximityBucket.sameProvince;
  SwipeService? _swipeService;

  @override
  void initState() {
    super.initState();
    _initBucketAndLoad();
    // Re-query the feed whenever the shell re-selects the Discover tab. The
    // IndexedStack keeps this widget alive, so without this the deck would
    // stay frozen on its first load and never surface users who became
    // eligible again (e.g. after a completed trade — post-trade re-discovery,
    // product decision #3).
    discoverRefreshTick.addListener(_onRefreshRequested);
  }

  /// Silent reload triggered by [discoverRefreshTick]. Keeps the current deck
  /// on screen (no full-screen spinner) while the new candidates load.
  void _onRefreshRequested() {
    if (!mounted) return;
    _loadFeed(silent: true);
  }

  @override
  void dispose() {
    discoverRefreshTick.removeListener(_onRefreshRequested);
    super.dispose();
  }

  /// Reads the persisted bucket from [SharedPreferences], then loads the feed.
  Future<void> _initBucketAndLoad() async {
    final saved = await loadProximityBucket();
    if (!mounted) return;
    setState(() => _bucket = saved);
    await _loadFeed();
  }

  /// Fetches candidates and their active items, then refreshes the UI.
  ///
  /// When [silent] is true the current deck stays on screen while the new
  /// candidates load (no full-screen spinner) — used for the tab-reselect
  /// refresh so re-entering Discover doesn't flash a loading state.
  Future<void> _loadFeed({bool silent = false}) async {
    setState(() {
      if (!silent) _isLoading = true;
      _error = null;
    });

    try {
      // 1. Resolve the current user — injectable for tests.
      //    Live path reads the uid via AuthProvider so this screen does not
      //    touch FirebaseAuth directly (WBS 4.4 locked acceptance).
      final fetchCurrentUser =
          widget.currentUserFetcherOverride ??
          _defaultCurrentUserFetcher(context.read<AuthProvider>());
      final me = await fetchCurrentUser();

      if (me == null) {
        // Not signed in or user document missing — show empty state.
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      try {
        _swipeService = SwipeService.fromAuth();
      } catch (_) {
        // Not signed in yet — swipes will be no-ops until the user signs in.
      }

      // 2. Build FeedService — use override or construct a live instance.
      //    A live FeedService needs a ProximityService; load it from assets.
      final feedService =
          widget.feedServiceOverride ??
          FeedService(proximityService: await ProximityService.load());

      final candidates = await feedService.candidatesForUser(me, _bucket);

      // 3. For each candidate, fetch their active items (first emission only).
      final itemService = widget.itemServiceOverride ?? ItemService();
      final itemsByUser = <String, List<Item>>{};
      await Future.wait(
        candidates.map((u) async {
          final items = await itemService.activeItemsForUser(u.uid).first;
          itemsByUser[u.uid] = items;
        }),
      );

      // 4. F18 — build the incoming-interest map (candidates who already
      //    swiped right on me, keyed by their uid → the item of mine they want).
      //    This is a non-critical enhancement: if the query fails, the deck
      //    still loads — it just shows no "Wants your X" badges.
      Map<String, IncomingInterest> interestMap = const {};
      try {
        final interestService =
            widget.interestServiceOverride ?? IncomingInterestService();
        interestMap = await interestService.interestMapForUser(me.uid);
      } catch (_) {
        interestMap = const {};
      }

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _itemsByUser = itemsByUser;
        _interestMap = interestMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Opens [UserDetailScreen] for the tapped card.
  void _onCardTap(app.User user) {
    final items = _itemsByUser[user.uid] ?? const [];
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => UserDetailScreen(
          user: user,
          items: items,
          onRightSwipe: () {
            Navigator.of(ctx).pop();
            _showItemPicker(user);
          },
          onLeftSwipe: () {
            Navigator.of(ctx).pop();
            _swipeService?.recordSwipe(user.uid, 'left');
          },
        ),
      ),
    );
  }

  /// Opens [ItemPickerModal] so the user can choose which item they want before
  /// the right-swipe is recorded.
  void _showItemPicker(app.User user) {
    final svc = _swipeService;
    if (svc == null) return;
    final items = _itemsByUser[user.uid] ?? const [];
    ItemPickerModal.show(
      context,
      targetUserName: user.displayName,
      targetUserId: user.uid,
      items: items,
      swipeService: svc,
    );
  }

  /// Called by [DiscoverScreen] when the user picks a new proximity filter.
  ///
  /// Persists the new selection (handled inside [ProximityFilterSheet]) and
  /// re-triggers [_loadFeed] with the new bucket.
  void _onBucketChanged(ProximityBucket newBucket) {
    setState(() => _bucket = newBucket);
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1D9E75)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadFeed,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DiscoverScreen(
      candidates: _candidates,
      itemsByUser: _itemsByUser,
      interestMap: _interestMap,
      proximityBucket: _bucket,
      onProximityChanged: _onBucketChanged,
      onCardTap: _onCardTap,
      onRightSwipe: (record) => _showItemPicker(record.user),
      swipeService: _swipeService,
    );
  }
}
