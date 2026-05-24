/// User Detail Screen — WBS 7.5
///
/// Full-screen modal showing the tapped user's profile and all their active
/// items. Tapping an item opens [ItemDetailSheet]. Right-swipe and left-swipe
/// buttons at the bottom mirror the deck-card buttons (WBS 7.3).
///
/// No age, no verification badge, no activity status, no km distance.
/// District is shown as "Thai · English, Province" (bucket-based, no GPS).
library;

import 'package:flutter/material.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/widgets/item_detail_sheet.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kDanger = Color(0xFFC44545);
const _kDangerSoft = Color(0xFFFCEBEB);

// ---------------------------------------------------------------------------
// UserDetailScreen
// ---------------------------------------------------------------------------

/// Displays a user's full profile, their active items grid, and swipe-action
/// buttons.
///
/// Callbacks:
///   [onBack]        — back-arrow tapped; parent pops the route.
///   [onRightSwipe]  — "I want to swap" (like) button tapped.
///   [onLeftSwipe]   — skip button tapped.
class UserDetailScreen extends StatefulWidget {
  final User user;

  /// Active items owned by [user].
  final List<Item> items;

  /// Called when the back arrow is tapped.
  final VoidCallback? onBack;

  /// Called when the right-swipe (like) button is tapped.
  final VoidCallback? onRightSwipe;

  /// Called when the left-swipe (skip) button is tapped.
  final VoidCallback? onLeftSwipe;

  const UserDetailScreen({
    super.key,
    required this.user,
    required this.items,
    this.onBack,
    this.onRightSwipe,
    this.onLeftSwipe,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  void _openItemSheet(Item item) {
    ItemDetailSheet.show(context, item: item, owner: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: Stack(
        children: [
          // Scrollable content with bottom padding so it clears the sticky bar.
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroPhoto(user: widget.user, onBack: widget.onBack),
                _ProfileBody(
                  user: widget.user,
                  items: widget.items,
                  onItemTap: _openItemSheet,
                ),
              ],
            ),
          ),

          // Sticky action bar — Skip (left) and Like (right)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StickyActionBar(
              onRightSwipe: widget.onRightSwipe,
              onLeftSwipe: widget.onLeftSwipe,
              userName: widget.user.displayName,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero photo section (360 px tall)
// ---------------------------------------------------------------------------

class _HeroPhoto extends StatelessWidget {
  final User user;
  final VoidCallback? onBack;

  const _HeroPhoto({required this.user, this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Stack(
        children: [
          // Background: photo or avatar colour fill
          Positioned.fill(
            child: user.photoUrl.isNotEmpty
                ? Image.network(
                    user.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) =>
                        _AvatarFill(name: user.displayName),
                  )
                : _AvatarFill(name: user.displayName),
          ),

          // Gradient scrim at the bottom for name legibility
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x80000000)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.displayName.isNotEmpty ? user.displayName : 'Unknown',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _districtLabel(user.homeDistrict),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xE6FFFFFF), // opacity 0.9
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Back button — top-left
          Positioned(
            top: 16,
            left: 16,
            child: Semantics(
              label: 'Back',
              button: true,
              child: GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: _kTextPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar fill — shown when photo is absent or fails to load
// ---------------------------------------------------------------------------

class _AvatarFill extends StatelessWidget {
  final String name;

  const _AvatarFill({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      color: _kGreenSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 80,
          fontWeight: FontWeight.w600,
          color: _kGreenDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile body — bio + items grid
// ---------------------------------------------------------------------------

class _ProfileBody extends StatelessWidget {
  final User user;
  final List<Item> items;
  final void Function(Item) onItemTap;

  const _ProfileBody({
    required this.user,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio
          if (user.bio.isNotEmpty)
            Text(
              user.bio,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _kTextPrimary,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 16),

          // Items section header
          Text(
            "${user.displayName.isNotEmpty ? user.displayName : 'Their'}'s items (${items.length})",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // 2-column item grid
          _ItemGrid(items: items, onItemTap: onItemTap),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items grid — 2 columns, tappable cards
// ---------------------------------------------------------------------------

class _ItemGrid extends StatelessWidget {
  final List<Item> items;
  final void Function(Item) onItemTap;

  const _ItemGrid({required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build rows of 2 from the flat list.
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: _ItemGridCard(item: left, onTap: () => onItemTap(left)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: right != null
                    ? _ItemGridCard(item: right, onTap: () => onItemTap(right))
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

// ---------------------------------------------------------------------------
// Individual item card in the grid
// ---------------------------------------------------------------------------

class _ItemGridCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const _ItemGridCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square photo thumbnail
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.photoUrl.isNotEmpty
                    ? Image.network(
                        item.photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) =>
                            _ThumbPlaceholder(item: item),
                      )
                    : _ThumbPlaceholder(item: item),
              ),
            ),
            const SizedBox(height: 8),
            // Item name
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Condition pill
            _ConditionPill(condition: item.condition),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thumbnail placeholder
// ---------------------------------------------------------------------------

class _ThumbPlaceholder extends StatelessWidget {
  final Item item;

  const _ThumbPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBorder,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 24, color: _kTextSecondary),
    );
  }
}

// ---------------------------------------------------------------------------
// Condition pill (reused locally — matches ItemDetailSheet design)
// ---------------------------------------------------------------------------

class _ConditionPill extends StatelessWidget {
  final ItemCondition condition;

  const _ConditionPill({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        condition.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _kTextSecondary,
          height: 1.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky action bar at the bottom
// ---------------------------------------------------------------------------

/// Contains Skip (left-swipe) and "I want to swap" (right-swipe) buttons.
/// The right-swipe button is the primary CTA (full-width, green).
/// The left-swipe button is a circular icon button to the left of it.
class _StickyActionBar extends StatelessWidget {
  final VoidCallback? onRightSwipe;
  final VoidCallback? onLeftSwipe;
  final String userName;

  const _StickyActionBar({
    this.onRightSwipe,
    this.onLeftSwipe,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          // Skip (left-swipe) — circular icon button
          Semantics(
            label: 'Skip',
            button: true,
            child: GestureDetector(
              onTap: onLeftSwipe,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _kSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kDangerSoft),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 24, color: _kDanger),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Like / right-swipe — full-width primary button
          Expanded(
            child: Semantics(
              label: 'Like',
              button: true,
              // excludeSemantics prevents the inner Text('I want to swap with …')
              // from creating a child semantics node that would shadow this label,
              // allowing find.bySemanticsLabel('Like') to work in tests.
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onRightSwipe,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _kGreenPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'I want to swap with $userName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// District label helper
// ---------------------------------------------------------------------------

/// Formats as "Thai · English, Province".
/// Falls back gracefully when fields are empty.
String _districtLabel(HomeDistrict d) {
  final th = d.districtNameTh;
  final en = d.districtNameEn;
  final province = d.provinceNameEn;

  if (th.isEmpty && en.isEmpty) return province.isNotEmpty ? province : '';
  if (th.isEmpty) return province.isNotEmpty ? '$en, $province' : en;
  if (en.isEmpty) return province.isNotEmpty ? '$th, $province' : th;
  return province.isNotEmpty ? '$th · $en, $province' : '$th · $en';
}
