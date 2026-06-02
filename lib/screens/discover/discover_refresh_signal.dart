/// Cross-widget signal that asks the Discover deck to re-query its feed.
///
/// The Discover tab loads its candidate list once in `initState`. Because the
/// shell keeps every tab alive inside an [IndexedStack], the deck would
/// otherwise never refresh while the app stays open — so a user who became
/// eligible again never reappears until the app is killed and reopened.
///
/// This matters for post-trade re-discovery (product decision #3): after a
/// completed trade the backend (`onItemTraded`, WBS 8.5) sweeps the mutual
/// swipes so the two swappers become eligible to rediscover each other once
/// either uploads a fresh active item. The client only reflects that once it
/// re-runs the feed query. Bumping this notifier — done by [MainShell] when
/// the Discover tab is (re-)selected — triggers a silent reload of the deck.
library;

import 'package:flutter/foundation.dart';

/// Incremented to request a Discover feed reload. Listeners (the Discover tab)
/// re-fetch candidates on every change. Starts at 0; the tab's own initial
/// load happens in `initState`, so the first tab selection is not double-loaded.
final ValueNotifier<int> discoverRefreshTick = ValueNotifier<int>(0);
