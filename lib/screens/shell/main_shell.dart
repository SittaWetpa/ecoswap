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

import 'package:flutter/material.dart';

import '../discover/discover_tab.dart';
import '../chats/match_list_screen.dart';
import '../impact/impact_placeholder_screen.dart';
import '../profile/profile_screen.dart';
import '../items/my_items_screen.dart';
import '../items/upload_item_screen.dart';
import '../items/edit_item_screen.dart';

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

  const MainShell({super.key, this.tabOverrides});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

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

  Widget _tabScreen(int index) {
    if (widget.tabOverrides != null &&
        widget.tabOverrides!.containsKey(index)) {
      return widget.tabOverrides![index]!;
    }
    switch (index) {
      case 0:
        return const DiscoverTab();
      case 1:
        return const MatchListScreen();
      case 2:
        return const ImpactPlaceholderScreen();
      case 3:
        return ProfileScreen(onMyItems: _handleMyItems);
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
