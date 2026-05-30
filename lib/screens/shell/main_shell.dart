/// Main Shell — persistent bottom navigation host.
///
/// Hosts the four top-level screens in an [IndexedStack] so each tab's state
/// (scroll position, loaded data) is preserved when the user switches tabs.
///
/// Tab order: 0 = Discover, 1 = Chats, 2 = Impact, 3 = Profile
///
/// The bottom navigation bar is built manually as a [Container]+[Row] to
/// match the prototype BottomNav component exactly (prototype/src/ui.jsx
/// lines 93–123). Flutter's built-in [BottomNavigationBar] is intentionally
/// not used.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/match_listener.dart';
import '../discover/discover_tab.dart';
import '../chats/match_list_screen.dart';
import '../impact/impact_dashboard_screen.dart';
import '../match/match_celebration_screen.dart';
import '../profile/profile_screen.dart';
import '../items/my_items_screen.dart';
import '../items/upload_item_screen.dart';
import '../items/edit_item_screen.dart';
import '../tutorial/tutorial_screen.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E5E0);
const _kTextSecondary = Color(0xFF6B6B66);

// ---------------------------------------------------------------------------
// Tab descriptor — keeps icon/label pairing in one place
// ---------------------------------------------------------------------------

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

const _kTabs = <_TabItem>[
  _TabItem(
    label: 'Discover',
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
  ),
  _TabItem(
    label: 'Chats',
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
  ),
  _TabItem(label: 'Impact', icon: Icons.eco_outlined, activeIcon: Icons.eco),
  _TabItem(
    label: 'Profile',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
];

// ---------------------------------------------------------------------------
// Cross-route tab signal
// ---------------------------------------------------------------------------

/// Lets code that lives on a route *above* the shell ask it to switch tabs.
///
/// The Swap Confirmed screen is reached through the QR flow, which is pushed
/// on top of [MainShell]. Its "See my impact" / "Back to chats" CTAs pop back
/// to the shell and then set this to the target tab index; the shell listens
/// and updates its selected index. The value is consumed (reset to null) on
/// read so the same tab can be requested again on a later swap.
final ValueNotifier<int?> shellTabRequest = ValueNotifier<int?>(null);

// ---------------------------------------------------------------------------
// MainShell
// ---------------------------------------------------------------------------

/// The root shell widget for authenticated users.
///
/// Renders a persistent [IndexedStack] with all four top-level screens and a
/// hand-built bottom navigation bar styled to match the prototype exactly.
///
/// Optional [tabOverrides] accepts a map of tab-index → widget. When provided,
/// the override replaces the default screen for that tab. Used in widget tests
/// so fakes can be injected without touching Firebase.
class MainShell extends StatefulWidget {
  /// Optional per-tab widget overrides, keyed by tab index (0–3).
  ///
  /// Intended for tests only. In production leave this null.
  final Map<int, Widget>? tabOverrides;

  /// Optional injectable stream of match proposals (WBS 8.4).
  ///
  /// - Production: leave null — the shell builds a [MatchListener] from the
  ///   current user's uid (via [AuthProvider]) and listens to its proposals.
  /// - Tests: inject a controllable stream to drive the match-celebration
  ///   overlay without touching Firebase.
  final Stream<MatchProposal>? matchProposalStreamOverride;

  const MainShell({
    super.key,
    this.tabOverrides,
    this.matchProposalStreamOverride,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  // WBS 8.4 — global match listener. Surfaces the celebration screen when a
  // new /matches/ doc involving the current user is created. Without this
  // wiring the backend creates the match doc but no UI ever fires.
  MatchListener? _matchListener;
  StreamSubscription<MatchProposal>? _proposalSub;
  bool _celebrationVisible = false;

  @override
  void initState() {
    super.initState();
    _setupMatchListener();
    shellTabRequest.addListener(_onTabRequest);
    _maybeShowTutorial();
  }

  /// On first run, present the How-It-Works tutorial over the shell, then
  /// persist the "seen" flag so it never auto-shows again.
  ///
  /// Skipped in widget tests (which inject [tabOverrides]) so the carousel
  /// never steals focus from a test's assertions and SharedPreferences is not
  /// touched. The Profile "How it works" row replays it on demand regardless.
  void _maybeShowTutorial() {
    if (widget.tabOverrides != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await hasSeenTutorial()) return;
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TutorialScreen(
            onDone: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
      await markTutorialSeen();
    });
  }

  /// Handles a tab-switch request raised from outside the shell's subtree
  /// (e.g. the Swap Confirmed screen's CTAs). Consumes the request so an
  /// identical later request still fires the listener.
  void _onTabRequest() {
    final requested = shellTabRequest.value;
    if (requested == null) return;
    shellTabRequest.value = null; // consume (re-fires listener → no-op)
    if (!mounted || requested < 0 || requested >= _kTabs.length) return;
    setState(() => _selectedIndex = requested);
  }

  /// Subscribes to match proposals. Uses an injected stream when provided
  /// (tests), otherwise builds a live [MatchListener] from the signed-in uid.
  ///
  /// Skipped entirely in widget tests that use [MainShell.tabOverrides] but do
  /// not inject a proposal stream, and when no user is signed in.
  void _setupMatchListener() {
    final override = widget.matchProposalStreamOverride;
    if (override != null) {
      _proposalSub = override.listen(_onMatchProposal);
      return;
    }
    if (widget.tabOverrides != null) return;

    String? uid;
    try {
      uid = context.read<AuthProvider>().currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    if (uid == null || uid.isEmpty) return;

    final listener = MatchListener(currentUserId: uid);
    _matchListener = listener;
    _proposalSub = listener.proposals.listen(_onMatchProposal);
    listener.start();
  }

  /// Shows the full-screen match celebration for [proposal] as a transparent
  /// overlay route. Guarded so two near-simultaneous emissions can't stack two
  /// celebrations on top of each other.
  Future<void> _onMatchProposal(MatchProposal proposal) async {
    if (!mounted || _celebrationVisible) return;
    _celebrationVisible = true;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, _, _) => MatchCelebrationScreen(
          proposal: proposal,
          onKeepSwiping: () => Navigator.of(context).maybePop(),
          onSendMessage: (_) {
            Navigator.of(context).maybePop();
            // Drop the user on the Chats tab, where the new match now appears.
            if (mounted) setState(() => _selectedIndex = 1);
          },
        ),
      ),
    );
    _celebrationVisible = false;
  }

  @override
  void dispose() {
    shellTabRequest.removeListener(_onTabRequest);
    _proposalSub?.cancel();
    _matchListener?.dispose();
    super.dispose();
  }

  /// Navigate to [MyItemsScreen], which itself navigates to [UploadItemScreen]
  /// or [EditItemScreen]. All three are pushed on top of the shell so the
  /// bottom nav is hidden during those flows.
  void _handleMyItems() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MyItemsScreen(
          onAdd: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const UploadItemScreen()),
          ),
          onEdit: (item) => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => EditItemScreen(item: item)),
          ),
        ),
      ),
    );
  }

  /// Replays the How-It-Works tutorial from the Profile "How it works" row.
  /// Replay mode shows a close (X) instead of "Skip"; done just pops.
  void _handleHowItWorks() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TutorialScreen(
          showSkip: false,
          onDone: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }

  Widget _tabScreen(int index) {
    if (widget.tabOverrides != null &&
        widget.tabOverrides!.containsKey(index)) {
      return widget.tabOverrides![index]!;
    }
    switch (index) {
      case 0:
        return const DiscoverTab();
      case 1:
        return MatchListScreen(
          onGoToDiscover: () => setState(() => _selectedIndex = 0),
        );
      case 2:
        return const ImpactDashboardScreen();
      case 3:
        return ProfileScreen(
          onMyItems: _handleMyItems,
          onHowItWorks: _handleHowItWorks,
        );
      default:
        throw RangeError.index(index, _kTabs, 'index', null, _kTabs.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List<Widget>.generate(_kTabs.length, _tabScreen),
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        bottomPadding: mediaQuery.padding.bottom,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BottomNav — hand-built to match prototype BottomNav (ui.jsx lines 93–123)
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final double bottomPadding;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('bottomNav'),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 64,
            child: Row(
              children: List<Widget>.generate(_kTabs.length, (i) {
                final tab = _kTabs[i];
                final isActive = i == selectedIndex;
                final color = isActive ? _kGreenPrimary : _kTextSecondary;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          size: 22,
                          color: color,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // Safe-area bottom padding (notched phones)
          if (bottomPadding > 0) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }
}
