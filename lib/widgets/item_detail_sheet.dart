/// Item Detail bottom sheet — WBS 7.5
///
/// Displays full details for a single item tapped from the User Detail screen.
/// Shows photo (4:3), name, category, condition pill, weight row (hidden when
/// weight is null), description, "looking for in return", and owner attribution.
///
/// No age, no trust score, no verification badge, no activity status.
library;

import 'package:flutter/material.dart';

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';

// ---------------------------------------------------------------------------
// Design tokens (matches discover_screen.dart)
// ---------------------------------------------------------------------------

const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);

// ---------------------------------------------------------------------------
// ItemDetailSheet
// ---------------------------------------------------------------------------

/// Bottom sheet showing full item details.
///
/// Height is approximately 70% of the screen (per prototype comment on
/// `ItemDetailSheet`). Presents all 7 item fields listed in the WBS 7.5
/// acceptance criteria:
///   photo, name, category, condition, weight (if present), description, wants.
///
/// The weight row is **hidden** when [Item.weight] is null per the WBS 7.5
/// Testing requirement: "Widget test: bottom sheet hides the weight row if
/// `weight == null`".
class ItemDetailSheet extends StatelessWidget {
  final Item item;
  final User owner;

  const ItemDetailSheet({super.key, required this.item, required this.owner});

  /// Convenience: show the sheet from any [BuildContext].
  static void show(
    BuildContext context, {
    required Item item,
    required User owner,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemDetailSheet(item: item, owner: owner),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.70,
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(
              0x1F000000,
            ), // shadow-modal: 0 8px 24px rgba(0,0,0,0.12)
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CloseRow(onClose: () => Navigator.of(context).pop()),
                  const SizedBox(height: 8),
                  _ItemPhoto(item: item),
                  const SizedBox(height: 24),
                  _ItemName(item: item),
                  const SizedBox(height: 8),
                  _CategoryConditionRow(item: item),
                  if (item.weight != null) ...[
                    const SizedBox(height: 16),
                    _WeightRow(weight: item.weight!),
                  ],
                  const SizedBox(height: 24),
                  _DescriptionSection(item: item, ownerName: owner.displayName),
                  const SizedBox(height: 24),
                  _WantsSection(item: item),
                  const SizedBox(height: 24),
                  _OwnerAttribution(owner: owner),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Close row
// ---------------------------------------------------------------------------

class _CloseRow extends StatelessWidget {
  final VoidCallback onClose;

  const _CloseRow({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: onClose,
        child: Semantics(
          label: 'Close',
          button: true,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kSurfaceAlt,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: const Icon(Icons.close, size: 20, color: _kTextPrimary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item photo (4:3 aspect ratio)
// ---------------------------------------------------------------------------

class _ItemPhoto extends StatelessWidget {
  final Item item;

  const _ItemPhoto({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: item.photoUrl.isNotEmpty
            ? Image.network(
                item.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, st) =>
                    _PhotoPlaceholder(item: item),
              )
            : _PhotoPlaceholder(item: item),
      ),
    );
  }
}

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
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _kTextTertiary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item name (h2 — 22px / 600)
// ---------------------------------------------------------------------------

class _ItemName extends StatelessWidget {
  final Item item;

  const _ItemName({required this.item});

  @override
  Widget build(BuildContext context) {
    return Text(
      item.name,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _kTextPrimary,
        height: 1.25,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category · condition row
// ---------------------------------------------------------------------------

class _CategoryConditionRow extends StatelessWidget {
  final Item item;

  const _CategoryConditionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          item.category.label,
          style: const TextStyle(fontSize: 12, color: _kTextSecondary),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(fontSize: 12, color: _kTextTertiary),
          ),
        ),
        _ConditionPill(condition: item.condition),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Condition pill — tiny / radius-full / surface-alt
// ---------------------------------------------------------------------------

class _ConditionPill extends StatelessWidget {
  final ItemCondition condition;

  const _ConditionPill({required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kSurfaceAlt,
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
// Weight row — only shown when weight != null
// ---------------------------------------------------------------------------

/// Shown only when [weight] is non-null. Hidden entirely when null so the test
/// "bottom sheet hides the weight row if weight == null" passes.
class _WeightRow extends StatelessWidget {
  final double weight;

  const _WeightRow({required this.weight});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.scale_outlined, size: 16, color: _kTextSecondary),
        const SizedBox(width: 6),
        Text(
          'Approx. $weight kg',
          style: const TextStyle(fontSize: 12, color: _kTextSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Description section
// ---------------------------------------------------------------------------

class _DescriptionSection extends StatelessWidget {
  final Item item;
  final String ownerName;

  const _DescriptionSection({required this.item, required this.ownerName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        item.description != null && item.description!.isNotEmpty
            ? Text(
                item.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: _kTextPrimary,
                  height: 1.5,
                ),
              )
            : Text(
                "${ownerName.isNotEmpty ? ownerName : 'Owner'} didn't add a description.",
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: _kTextTertiary,
                  height: 1.5,
                ),
              ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "Looking for in return" section
// ---------------------------------------------------------------------------

class _WantsSection extends StatelessWidget {
  final Item item;

  const _WantsSection({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Looking for in return',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        item.wants != null && item.wants!.isNotEmpty
            ? Text(
                item.wants!,
                style: const TextStyle(
                  fontSize: 14,
                  color: _kTextPrimary,
                  height: 1.5,
                ),
              )
            : const Text(
                'Open to anything.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: _kTextTertiary,
                  height: 1.5,
                ),
              ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Owner attribution
// ---------------------------------------------------------------------------

class _OwnerAttribution extends StatelessWidget {
  final User owner;

  const _OwnerAttribution({required this.owner});

  @override
  Widget build(BuildContext context) {
    final initial = owner.displayName.isNotEmpty
        ? owner.displayName.substring(0, 1).toUpperCase()
        : '?';

    return Row(
      children: [
        // Mini avatar (24px circle)
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: _kGreenSoft,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: owner.photoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    owner.photoUrl,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context2, err, st) => Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _kGreenDark,
                      ),
                    ),
                  ),
                )
              : Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _kGreenDark,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          'Owned by ${owner.displayName.isNotEmpty ? owner.displayName : 'owner'}',
          style: const TextStyle(fontSize: 12, color: _kTextSecondary),
        ),
      ],
    );
  }
}
