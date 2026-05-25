/// Item Picker Modal — WBS 8.2
///
/// Single-select bottom sheet (~70 % of screen height) that fires when the
/// user swipes right on a candidate card.  The user must pick exactly ONE of
/// the target user's active items before the swipe is recorded.  Cancelling
/// the modal (close button, backdrop tap, or Android back gesture) aborts
/// the swipe entirely — no swipe document is written.
///
/// Acceptance criteria (per WBS 8.2):
///   - Shows all active items of the target user.
///   - Only one item can be selected (single-select, NOT multi-select).
///   - Confirm button is disabled until exactly one item is selected.
///   - Cancel aborts the swipe completely (no Firestore write).
///   - Confirm calls [SwipeService.recordSwipe] with direction 'right' and
///     the chosen [desiredItemId].
///
/// Widget names match the prototype: [ItemPickerModal] (PickerScreen in JSX)
/// and [ItemPickCard] (ItemPickCard in JSX).
library;

import 'package:flutter/material.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/services/swipe_service.dart';

// ---------------------------------------------------------------------------
// Design tokens (Style Guide §2)
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// ItemPickerModal
// ---------------------------------------------------------------------------

/// Bottom-sheet item picker, corresponding to [PickerScreen] in the JSX
/// prototype.
///
/// Show with [ItemPickerModal.show]:
/// ```dart
/// final pickedId = await ItemPickerModal.show(
///   context,
///   targetUserName: 'Fah',
///   targetUserId: 'uid-fah',
///   items: fahsActiveItems,
///   swipeService: mySwipeService,
/// );
/// // pickedId is non-null when the user confirmed, null when cancelled.
/// ```
///
/// The modal writes the swipe via [swipeService] before returning so the
/// caller does not have to do anything extra after [await].
class ItemPickerModal extends StatefulWidget {
  /// Display name of the user whose items are being shown.
  final String targetUserName;

  /// Firestore UID of the target user (passed to [SwipeService.recordSwipe]).
  final String targetUserId;

  /// Active items belonging to the target user.  Only active items should be
  /// passed; the modal renders whatever list it receives.
  final List<Item> items;

  /// Service used to write the swipe when the user confirms a selection.
  /// Injected so tests can run without a real Firebase project.
  final SwipeService swipeService;

  const ItemPickerModal({
    super.key,
    required this.targetUserName,
    required this.targetUserId,
    required this.items,
    required this.swipeService,
  });

  /// Shows the picker as a modal bottom sheet.
  ///
  /// Returns the [Item.id] of the selected item when the user confirms, or
  /// `null` when the user cancels.  The Firestore swipe document is written
  /// inside the modal before this future resolves — the caller does not need
  /// to call [SwipeService.recordSwipe] again.
  static Future<String?> show(
    BuildContext context, {
    required String targetUserName,
    required String targetUserId,
    required List<Item> items,
    required SwipeService swipeService,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(102), // ~40 % opacity
      isDismissible: true,
      builder: (_) => ItemPickerModal(
        targetUserName: targetUserName,
        targetUserId: targetUserId,
        items: items,
        swipeService: swipeService,
      ),
    );
  }

  @override
  State<ItemPickerModal> createState() => _ItemPickerModalState();
}

class _ItemPickerModalState extends State<ItemPickerModal> {
  /// Currently selected item ID.  Null until the user taps an item.
  String? _selectedItemId;

  void _handleItemTap(String itemId) {
    setState(() => _selectedItemId = itemId);
  }

  Future<void> _handleConfirm() async {
    final picked = _selectedItemId;
    if (picked == null) return; // button is disabled, but guard defensively

    await widget.swipeService.recordSwipe(
      widget.targetUserId,
      'right',
      desiredItemId: picked,
    );

    if (mounted) Navigator.of(context).pop(picked);
  }

  void _handleCancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.70,
      child: Container(
        decoration: const BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              // shadow-modal: 0 8px 24px rgba(0,0,0,0.12)
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle — 12 px from top (prototype comment)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),

            // Header area with close button and text — 24 px below handle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Stack(
                children: [
                  // Close X — top-left (prototype: position absolute, top:16
                  // from sheet edge, left:16 from sheet edge; accounting for
                  // the 12+4=16 px handle zone, we use Positioned offset 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Semantics(
                      label: 'Close',
                      button: true,
                      child: GestureDetector(
                        onTap: _handleCancel,
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 24,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Header text indented past the close button
                  Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "What of ${widget.targetUserName}'s do you want?",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick one item to send an anonymous nudge. '
                          '${widget.targetUserName} will see your interest in '
                          'this item if they swipe back.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _kTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Item grid — 20 px below subhead, fills remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    // Cards are taller than square to fit name + condition pill
                    childAspectRatio: 0.80,
                  ),
                  itemCount: widget.items.length,
                  itemBuilder: (_, i) {
                    final item = widget.items[i];
                    return ItemPickCard(
                      key: ValueKey(item.id),
                      item: item,
                      selected: _selectedItemId == item.id,
                      onTap: () => _handleItemTap(item.id),
                    );
                  },
                ),
              ),
            ),

            // Footer — caption + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "You can change your mind later — nothing is locked yet.",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _kTextTertiary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  _ConfirmButton(
                    enabled: _selectedItemId != null,
                    targetUserName: widget.targetUserName,
                    onPressed: _handleConfirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ItemPickCard
// ---------------------------------------------------------------------------

/// Single item card inside the picker grid.
///
/// Selected state: 2 px green border + checkmark badge top-right of photo.
/// Unselected state: 2 px transparent border (reserves space so layout is
/// stable during selection changes).
///
/// Corresponds to [ItemPickCard] in the JSX prototype.
class ItemPickCard extends StatelessWidget {
  final Item item;
  final bool selected;

  /// Called when the user taps this card.
  final VoidCallback onTap;

  const ItemPickCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kGreenPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square photo with optional checkmark overlay
            _ItemPhoto(item: item, selected: selected),
            const SizedBox(height: 12),
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
// Item photo with checkmark overlay
// ---------------------------------------------------------------------------

class _ItemPhoto extends StatelessWidget {
  final Item item;
  final bool selected;

  const _ItemPhoto({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Square photo / placeholder
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.photoUrl.isNotEmpty
                ? Image.network(
                    item.photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context2, err, stackTrace) =>
                        _PhotoPlaceholder(item: item),
                  )
                : _PhotoPlaceholder(item: item),
          ),
        ),

        // Selected checkmark badge — top-right corner of photo
        if (selected)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: _kGreenPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Photo placeholder
// ---------------------------------------------------------------------------

class _PhotoPlaceholder extends StatelessWidget {
  final Item item;

  const _PhotoPlaceholder({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurfaceAlt,
      alignment: Alignment.center,
      child: Text(
        item.category.label.toLowerCase(),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _kTextTertiary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Condition pill
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
// Confirm button
// ---------------------------------------------------------------------------

class _ConfirmButton extends StatelessWidget {
  final bool enabled;
  final String targetUserName;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.enabled,
    required this.targetUserName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreenPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kGreenPrimary,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Send interest to $targetUserName',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
