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
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart' as app;
import 'package:ecoswap/screens/discover/discover_screen.dart';
import 'package:ecoswap/services/feed_service.dart';
import 'package:ecoswap/services/item_service.dart';
import 'package:ecoswap/services/proximity_service.dart';
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

/// Live [CurrentUserFetcher] — reads from [FirebaseAuth] + [FirebaseFirestore].
CurrentUserFetcher _defaultCurrentUserFetcher() {
  return () async {
    final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
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

  const DiscoverTab({
    super.key,
    this.feedServiceOverride,
    this.itemServiceOverride,
    this.currentUserFetcherOverride,
  });

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  List<app.User> _candidates = [];
  Map<String, List<Item>> _itemsByUser = {};
  bool _isLoading = true;
  String? _error;
  ProximityBucket _bucket = ProximityBucket.sameProvince;

  @override
  void initState() {
    super.initState();
    _initBucketAndLoad();
  }

  /// Reads the persisted bucket from [SharedPreferences], then loads the feed.
  Future<void> _initBucketAndLoad() async {
    final saved = await loadProximityBucket();
    if (!mounted) return;
    setState(() => _bucket = saved);
    await _loadFeed();
  }

  /// Fetches candidates and their active items, then refreshes the UI.
  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Resolve the current user — injectable for tests.
      final fetchCurrentUser =
          widget.currentUserFetcherOverride ?? _defaultCurrentUserFetcher();
      final me = await fetchCurrentUser();

      if (me == null) {
        // Not signed in or user document missing — show empty state.
        if (mounted) setState(() => _isLoading = false);
        return;
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

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _itemsByUser = itemsByUser;
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
      proximityBucket: _bucket,
      onProximityChanged: _onBucketChanged,
    );
  }
}
