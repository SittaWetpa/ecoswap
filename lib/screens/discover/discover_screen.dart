/// Discover Screen — WBS 7.3
///
/// Hosts the swipe-card deck using [AppinioSwiper]. Each card shows:
///   - User photo area
///   - District pill (bucket-based, no km/GPS)
///   - Display name
///   - Horizontal item preview (first 1–3 active items)
///
/// Gesture routing:
///   - Right-swipe  → opens [onRightSwipe] callback (item picker, WBS 8.2)
///   - Left-swipe   → calls [onLeftSwipe] callback (write swipe doc, WBS 8.1)
///   - Tap on card  → calls [onCardTap] callback (User Detail, WBS 7.5)
///
/// No fabricated UI: no "verified", no "active now", no age, no km.
library;

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';

import 'package:ecoswap/models/incoming_interest.dart';
import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/services/swipe_service.dart';
import 'package:ecoswap/widgets/empty_state.dart';
import 'package:ecoswap/widgets/proximity_filter_sheet.dart';

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
const _kTextTertiary = Color(0xFFA0A09B);
const _kDanger = Color(0xFFC44545);
const _kDangerSoft = Color(0xFFFCEBEB);

// ---------------------------------------------------------------------------
// SwipeRecord — passed to onLeftSwipe / onRightSwipe callbacks
// ---------------------------------------------------------------------------

/// Captures the user and direction of a completed swipe.
///
/// The parent uses [direction] to write the Firestore swipe document
/// (`direction: 'left'` or `direction: 'right'`). Passing the direction
/// explicitly here satisfies WBS 7.3's test requirement: "left-swipe writes
/// a swipe doc with direction: 'left'."
class SwipeRecord {
  final User user;

  /// `'left'` for a skip swipe; `'right'` for a want swipe.
  final String direction;

  const SwipeRecord({required this.user, required this.direction});
}

// ---------------------------------------------------------------------------
// SwipeCard widget
// ---------------------------------------------------------------------------

/// A single card in the swipe deck.
///
/// Displays user photo area, district pill, display name, and a horizontal
/// row of up to 3 item thumbnails. Tapping the card fires [onTap].
///
/// No age, no verification badge, no "active now", no km distance.
class SwipeCard extends StatelessWidget {
  final User user;
  final List<Item> items;

  /// Called when the user taps the card without swiping.
  final VoidCallback? onTap;

  /// F18 — when this candidate has already swiped right on the current user,
  /// the card shows a green "Wants your {item}" badge. Null = no incoming
  /// interest (the card renders normally).
  final IncomingInterest? incomingInterest;

  const SwipeCard({
    super.key,
    required this.user,
    required this.items,
    this.onTap,
    this.incomingInterest,
  });

  @override
  Widget build(BuildContext context) {
    // Photo:info split mirrors the prototype (discover.jsx line 13): 52/48
    // normally, growing to 60/40 in incoming-interest mode so the green
    // "Wants your X" badge has room to breathe.
    final bool hasInterest = incomingInterest != null;
    final int photoFlex = hasInterest ? 60 : 52;
    final int infoFlex = hasInterest ? 40 : 48;
    // MergeSemantics collapses the card into a single tappable node that
    // carries a label (the merged name/district/item text) and the button
    // role — so screen readers announce it as one actionable card and it
    // satisfies the labeled-tap-target accessibility guideline (the bare
    // GestureDetector node had a tap action but no label).
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
              boxShadow: const [
                BoxShadow(
                  // shadow-card: 0 1px 3px rgba(0,0,0,0.06)
                  color: Color(0x0F000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            // Column with Expanded children so the photo/info split fills the
            // card. The outer Container has clipBehavior: Clip.hardEdge so any
            // pixel rounding overflow is silently clipped rather than reported.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: photoFlex,
                  child: _PhotoSection(
                    user: user,
                    incomingInterest: incomingInterest,
                  ),
                ),
                Expanded(
                  flex: infoFlex,
                  child: _InfoSection(user: user, items: items),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo section (top ~52% of card)
// ---------------------------------------------------------------------------

class _PhotoSection extends StatelessWidget {
  final User user;

  /// F18 — non-null when this candidate has already swiped right on the
  /// current user. Flips the district pill to the top-left and shows the
  /// "Wants your {item}" badge top-right (matching the prototype).
  final IncomingInterest? incomingInterest;

  const _PhotoSection({required this.user, this.incomingInterest});

  @override
  Widget build(BuildContext context) {
    final interest = incomingInterest;
    return Stack(
      children: [
        // Photo / placeholder
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: user.photoUrl.isNotEmpty
                ? Image.network(
                    user.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, st) =>
                        _AvatarPlaceholder(name: user.displayName),
                  )
                : _AvatarPlaceholder(name: user.displayName),
          ),
        ),

        // Top overlays. With incoming interest, the district pill (left) and
        // the "Wants your {item}" badge (right) share a single full-width row
        // so they shrink/ellipsise instead of overlapping — long Thai district
        // names previously ran under the badge. Without interest, the pill
        // sits alone at the top-right (prototype).
        if (interest != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Flexible(child: _DistrictPill(homeDistrict: user.homeDistrict)),
                const SizedBox(width: 8),
                Flexible(child: _InterestBadge(itemName: interest.itemName)),
              ],
            ),
          )
        else
          Positioned(
            top: 12,
            right: 12,
            child: _DistrictPill(homeDistrict: user.homeDistrict),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Incoming-interest badge — F18 "Wants your {item}"
// ---------------------------------------------------------------------------

/// Green badge shown on a candidate's card when they have already swiped right
/// on the current user. Mirrors the prototype's interest highlight
/// (`discover.jsx` lines 56–69).
class _InterestBadge extends StatelessWidget {
  final String itemName;

  const _InterestBadge({required this.itemName});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _kGreenPrimary,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(
              // 0 2px 6px rgba(15,110,86,0.35)
              color: Color(0x590F6E56),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Wants your $itemName',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info section (bottom ~48% of card)
// ---------------------------------------------------------------------------

class _InfoSection extends StatelessWidget {
  final User user;
  final List<Item> items;

  const _InfoSection({required this.user, required this.items});

  @override
  Widget build(BuildContext context) {
    // Column layout matching the prototype info section (discover.jsx 108-136):
    // name + district at the top, then the items block which expands to fill
    // the remaining height. The thumbnails (inside _ItemsRow) take that
    // available height rather than forcing height == width — so a single item
    // no longer balloons into a full-width square that overflows the section
    // and hides the name. Expanding the items block also guarantees the Column
    // is fully bounded, so there is no overflow.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.displayName.isNotEmpty ? user.displayName : 'Unknown',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // District caption under name — matches prototype info section
          Text(
            _districtLabel(user.homeDistrict),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Expanded(child: _ItemsRow(items: items)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items row — first 1–3 items with thumbnails
// ---------------------------------------------------------------------------

class _ItemsRow extends StatelessWidget {
  final List<Item> items;

  const _ItemsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final displayItems = items.take(3).toList();
    final extra = items.length > 3 ? items.length - 3 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexible so a long label truncates instead of overflowing the
            // row (the "tap to see all" affordance always stays visible).
            Expanded(
              child: Text(
                'Swapping ${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kTextTertiary,
                  letterSpacing: 0.5,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'tap to see all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kGreenPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Thumbnails fill the remaining height of the info section. Each
        // occupies an equal share of the width (Expanded) and is cover-cropped
        // to that box, so 1 item → one wide thumbnail, 2 → two ~squares, 3 →
        // three narrower ones — never taller than the space allows.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...displayItems.map(
                (item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ItemThumb(item: item),
                  ),
                ),
              ),
              if (extra > 0)
                SizedBox(
                  width: 60,
                  // Top-align the "+N" square so it lines up with the top of
                  // the thumbnails (prototype: alignSelf 'flex-start').
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kSurfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+$extra',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Item thumbnail
// ---------------------------------------------------------------------------

class _ItemThumb extends StatelessWidget {
  final Item item;

  const _ItemThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    // Image fills the available box (its column width × the height handed
    // down by the Expanded items row) and is cover-cropped — mirroring the
    // prototype's height-capped `width:100%` thumbnail. The caption sits
    // below at a fixed height; Expanded on the image absorbs the rest so the
    // column is always bounded (no overflow).
    final Widget image = item.photoUrl.isNotEmpty
        ? Image.network(
            item.photoUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, e, st) => _thumbPlaceholder(),
          )
        : _thumbPlaceholder();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: double.infinity, child: image),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kTextPrimary,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: _kSurfaceAlt,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 20, color: _kTextTertiary),
    );
  }
}

// ---------------------------------------------------------------------------
// District pill
// ---------------------------------------------------------------------------

/// District pill shown on the card photo — format: "Thai · English, Province"
///
/// Format per WBS 5.2: `districtNameTh · districtNameEn, provinceNameEn`
class _DistrictPill extends StatelessWidget {
  final HomeDistrict homeDistrict;

  const _DistrictPill({required this.homeDistrict});

  @override
  Widget build(BuildContext context) {
    final label = _districtLabel(homeDistrict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(217), // rgba(255,255,255,0.85)
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: _kTextPrimary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary,
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats the district pill label as "Thai · English, Province".
///
/// Example: "บางมด · Bang Mod, Bangkok"
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

// ---------------------------------------------------------------------------
// Avatar placeholder
// ---------------------------------------------------------------------------

class _AvatarPlaceholder extends StatelessWidget {
  final String name;

  const _AvatarPlaceholder({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      color: _kGreenSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          color: _kGreenDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DiscoverScreen
// ---------------------------------------------------------------------------

/// Host screen for the swipe deck.
///
/// Integrates:
/// - [AppinioSwiper] for gesture-based swiping
/// - [ProximityPill] and [ProximityFilterSheet] for proximity filtering
/// - Action buttons (Skip / Like) below the deck
///
/// Routing callbacks are injected so this widget can be unit-tested without
/// a real navigator:
///   [onRightSwipe] — called when user swipes right (opens item picker)
///   [onLeftSwipe]  — called when user swipes left (writes swipe doc)
///   [onCardTap]    — called when user taps a card (opens User Detail)
class DiscoverScreen extends StatefulWidget {
  /// The list of candidate [User]s to show in the deck.
  final List<User> candidates;

  /// Items keyed by [User.uid]. Only active items should be included.
  final Map<String, List<Item>> itemsByUser;

  /// F18 — incoming interest keyed by candidate [User.uid]. A candidate present
  /// in this map has already swiped right on the current user; their card shows
  /// a "Wants your {item}" badge. Defaults to empty (no incoming interest).
  final Map<String, IncomingInterest> interestMap;

  /// Currently selected proximity bucket.
  final ProximityBucket proximityBucket;

  /// Called when the proximity filter changes. Parent is responsible for
  /// reloading the feed.
  final ValueChanged<ProximityBucket>? onProximityChanged;

  /// Called when the user swipes right. Receives a [SwipeRecord] with
  /// [SwipeRecord.direction] == `'right'`.
  final ValueChanged<SwipeRecord>? onRightSwipe;

  /// Called when the user swipes left. Receives a [SwipeRecord] with
  /// [SwipeRecord.direction] == `'left'`.
  final ValueChanged<SwipeRecord>? onLeftSwipe;

  /// Called when the user taps a card (without swiping).
  final ValueChanged<User>? onCardTap;

  /// Injectable [SwipeService] for writing swipe documents to Firestore.
  ///
  /// Left-swipes are recorded immediately inside [DiscoverScreen] before the
  /// next card animates in (WBS 8.1 acceptance criterion 3).  Right-swipes
  /// still surface via [onRightSwipe] so the item picker (WBS 8.2) can supply
  /// the [desiredItemId] before [SwipeService.recordSwipe] is called.
  ///
  /// Pass `null` (or omit) in widget tests that do not exercise Firestore.
  final SwipeService? swipeService;

  const DiscoverScreen({
    super.key,
    required this.candidates,
    required this.itemsByUser,
    this.interestMap = const {},
    this.proximityBucket = ProximityBucket.sameProvince,
    this.onProximityChanged,
    this.onRightSwipe,
    this.onLeftSwipe,
    this.onCardTap,
    this.swipeService,
  });

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final AppinioSwiperController _swiperController;

  /// Mutable deck — cards are removed as the user swipes through.
  late List<User> _deck;

  /// Tracks horizontal drag delta for the WANT/SKIP overlay.
  /// Positive = dragging right (WANT); negative = dragging left (SKIP).
  double _dragDx = 0.0;

  @override
  void initState() {
    super.initState();
    _swiperController = AppinioSwiperController();
    _deck = List<User>.from(widget.candidates);
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidates != widget.candidates) {
      setState(() {
        _deck = List<User>.from(widget.candidates);
      });
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  void _handleSwipeEnd(
    int previousIndex,
    int targetIndex,
    SwiperActivity activity,
  ) {
    if (activity is! Swipe) return;
    if (previousIndex >= _deck.length) return;

    final swipedUser = _deck[previousIndex];
    final direction = activity.direction;

    if (direction == AxisDirection.right) {
      widget.onRightSwipe?.call(
        SwipeRecord(user: swipedUser, direction: 'right'),
      );
    } else if (direction == AxisDirection.left) {
      // Write the swipe document BEFORE the next card animates in (WBS 8.1).
      // Fire-and-forget: the Future is intentionally unawaited here because
      // _handleSwipeEnd is synchronous. The card removal and Firestore write
      // are independent — a write failure does not block the UI.
      widget.swipeService?.recordSwipe(swipedUser.uid, 'left');

      widget.onLeftSwipe?.call(
        SwipeRecord(user: swipedUser, direction: 'left'),
      );
    }

    setState(() {
      _dragDx = 0.0;
      // Remove the card that was swiped.
      if (previousIndex < _deck.length) {
        _deck.removeAt(previousIndex);
      }
    });
  }

  void _handleEnd() {
    // Feed exhausted — deck is now empty. setState ensures empty state shows.
    setState(() {});
  }

  void _openProximitySheet() {
    ProximityFilterSheet.show(
      context,
      current: widget.proximityBucket,
      onChanged: (bucket) {
        widget.onProximityChanged?.call(bucket);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildFilterRow(),
            Expanded(child: _deck.isEmpty ? _buildEmptyState() : _buildDeck()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar — wordmark only (no cog, no info icon per CLAUDE.md locked decision)
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      height: 56,
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'EcoSwap',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _kGreenPrimary,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter row — proximity pill only
  // ---------------------------------------------------------------------------

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Row(
        children: [
          ProximityPill(
            bucket: widget.proximityBucket,
            onTap: _openProximitySheet,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card deck
  // ---------------------------------------------------------------------------

  Widget _buildDeck() {
    return Listener(
      // Track horizontal pointer delta so the WANT/SKIP overlay can fade in.
      // Listener sits below the gesture arena, so it never competes with
      // AppinioSwiper's own pan recognizer.
      onPointerMove: (event) {
        setState(() => _dragDx += event.delta.dx);
      },
      onPointerUp: (_) => setState(() => _dragDx = 0.0),
      onPointerCancel: (_) => setState(() => _dragDx = 0.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Expanded(
              child: AppinioSwiper(
                key: ValueKey(_deck.length),
                controller: _swiperController,
                cardCount: _deck.length,
                swipeOptions: const SwipeOptions.symmetric(horizontal: true),
                backgroundCardCount: 1,
                backgroundCardScale: 0.96,
                backgroundCardOffset: const Offset(0, 8),
                onSwipeEnd: _handleSwipeEnd,
                onEnd: _handleEnd,
                cardBuilder: (context, index) {
                  if (index >= _deck.length) return const SizedBox.shrink();
                  final user = _deck[index];
                  final items = widget.itemsByUser[user.uid] ?? const [];
                  // Only the top card (index == 0) shows the drag overlay.
                  return Stack(
                    children: [
                      SwipeCard(
                        key: ValueKey(user.uid),
                        user: user,
                        items: items,
                        incomingInterest: widget.interestMap[user.uid],
                        onTap: () => widget.onCardTap?.call(user),
                      ),
                      if (index == 0) _SwipeOverlay(dx: _dragDx),
                    ],
                  );
                },
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons — Skip (left) and Like (right)
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Skip button
          _SwipeActionButton(
            onTap: () => _swiperController.swipeLeft(),
            iconColor: _kDanger,
            borderColor: _kDangerSoft,
            icon: Icons.close,
            semanticLabel: 'Skip',
          ),
          const SizedBox(width: 24),
          // Like button
          _SwipeActionButton(
            onTap: () => _swiperController.swipeRight(),
            iconColor: _kGreenPrimary,
            borderColor: _kGreenSoft,
            icon: Icons.favorite_outline,
            semanticLabel: 'Like',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state — WBS 7.6
  // ---------------------------------------------------------------------------

  /// Shown when [_deck] is empty (feed query returned zero candidates).
  /// Uses the reusable [EmptyState] widget (WBS 7.6 deliverable).
  /// Copy is locked per locked-decision rules (no "search radius" language):
  ///   headline:     "No one nearby yet"
  ///   description:  "Try widening your proximity filter, or check back later —
  ///                  new swappers join every day."
  ///   cta:          "Widen search"  →  opens the proximity filter sheet
  Widget _buildEmptyState() {
    return EmptyState(
      icon: const Icon(Icons.explore),
      headline: 'No one nearby yet',
      description:
          'Try widening your proximity filter, or check back later — '
          'new swappers join every day.',
      ctaLabel: 'Widen search',
      onCta: _openProximitySheet,
    );
  }
}

// ---------------------------------------------------------------------------
// WANT / SKIP drag overlay
// ---------------------------------------------------------------------------

/// Fades in a stamped label overlay as the user drags a card horizontally.
///
/// - Dragging right (positive [dx]) → green "WANT" stamp on the left edge.
/// - Dragging left  (negative [dx]) → red  "SKIP" stamp on the right edge.
///
/// The overlay is transparent until the drag exceeds [_kOverlayThreshold] px,
/// then linearly reaches full opacity at [_kOverlayMaxDx] px. This matches the
/// behaviour shown in `discover.jsx` lines 88–104.
class _SwipeOverlay extends StatelessWidget {
  final double dx;

  const _SwipeOverlay({required this.dx});

  static const double _kOverlayThreshold = 20.0;
  static const double _kOverlayMaxDx = 120.0;

  @override
  Widget build(BuildContext context) {
    final absDx = dx.abs();
    if (absDx < _kOverlayThreshold) return const SizedBox.shrink();

    final opacity =
        ((absDx - _kOverlayThreshold) / (_kOverlayMaxDx - _kOverlayThreshold))
            .clamp(0.0, 1.0);
    final isWant = dx > 0;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: opacity,
          duration: Duration.zero,
          child: Container(
            decoration: BoxDecoration(
              color: isWant
                  ? const Color(0x221D9E75) // green tint
                  : const Color(0x22C44545), // red tint
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: isWant ? Alignment.topLeft : Alignment.topRight,
            padding: const EdgeInsets.all(20),
            child: _StampLabel(
              text: isWant ? 'WANT' : 'SKIP',
              color: isWant ? _kGreenPrimary : _kDanger,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rotated stamp-style label used by [_SwipeOverlay].
class _StampLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _StampLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.35, // ~–20 degrees, matching prototype stamp tilt
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 2,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe action button
// ---------------------------------------------------------------------------

class _SwipeActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color iconColor;
  final Color borderColor;
  final IconData icon;
  final String semanticLabel;

  const _SwipeActionButton({
    required this.onTap,
    required this.iconColor,
    required this.borderColor,
    required this.icon,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _kSurface,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: iconColor),
        ),
      ),
    );
  }
}
