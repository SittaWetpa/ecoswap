/// Match Celebration Screen — WBS 8.4
///
/// Full-screen celebration overlay shown when a new match is detected.
/// Displays both items being swapped, both display names, and CTAs to
/// start chatting or keep swiping.
///
/// Prototype reference: `prototype/src/screens/match.jsx` — `MatchScreen`.
///
/// Acceptance criteria:
///   - Shows both items (photos, names), both display names.
///   - "Send a message" CTA navigates to the chat for this match.
///   - "Keep swiping" dismisses back to Discover.
///   - Screen is shown at most once per matchId (one-time display).
library;

import 'package:flutter/material.dart';

import 'package:ecoswap/constants/impact.dart';
import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// MatchProposal — view model for the celebration screen
// ---------------------------------------------------------------------------

/// All display-ready data for one match celebration.
///
/// Produced by [MatchListener] after resolving the Firestore match doc plus
/// the two item docs and the counterparty user doc.  Injected directly in
/// widget tests.
class MatchProposal {
  /// Firestore matchId — used for deduplication in `shared_preferences`.
  final String matchId;

  /// The other party in the match.
  final User otherUser;

  /// The item the current user is giving (what the other person wants).
  final Item myItem;

  /// The item the current user is getting (what the current user wants).
  final Item theirItem;

  const MatchProposal({
    required this.matchId,
    required this.otherUser,
    required this.myItem,
    required this.theirItem,
  });
}

// ---------------------------------------------------------------------------
// MatchCelebrationScreen
// ---------------------------------------------------------------------------

/// Full-screen celebration overlay for a newly detected match.
///
/// Widget names match the prototype: [MatchCelebrationScreen] corresponds to
/// [MatchScreen] in `match.jsx`.
///
/// All dependencies are injected for testability:
///   [proposal]       — display data for this match.
///   [onSendMessage]  — called when the user taps "Send a message".
///   [onKeepSwiping]  — called when the user taps "Keep swiping".
class MatchCelebrationScreen extends StatelessWidget {
  final MatchProposal proposal;

  /// Called with the matchId when the user taps "Send a message".
  final void Function(String matchId)? onSendMessage;

  /// Called when the user taps "Keep swiping".
  final VoidCallback? onKeepSwiping;

  const MatchCelebrationScreen({
    super.key,
    required this.proposal,
    this.onSendMessage,
    this.onKeepSwiping,
  });

  // Estimated CO₂ savings from the item they're receiving.
  double _estimatedCo2() {
    final item = proposal.theirItem;
    final weight = item.weight ?? (typicalWeight[item.category.value] ?? 0.5);
    final intensity = co2Intensity[item.category.value] ?? 5.0;
    return weight * intensity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Headline
              _buildHeadline(),
              const SizedBox(height: 28),
              // Trade card
              _buildTradeCard(),
              const SizedBox(height: 24),
              // CTAs
              _buildCtas(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Headline section
  // ---------------------------------------------------------------------------

  Widget _buildHeadline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "It's a match!" — matches display size (32px, w600) in style guide
        Text(
          "It's a match!",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 2,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "You're swapping with\n${proposal.otherUser.displayName}.",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "You both want each other's items.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Trade card
  // ---------------------------------------------------------------------------

  Widget _buildTradeCard() {
    final co2 = _estimatedCo2();

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            // shadow-modal: 0 8px 24px rgba(0,0,0,0.12)
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Two-column item display with swap arrow in the middle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // My side — "You give"
              Expanded(
                child: _ItemSide(
                  avatarInitial: 'Y',
                  label: 'You give',
                  item: proposal.myItem,
                ),
              ),
              // Swap arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 46), // align with item photo top
                    const Icon(
                      Icons.swap_horiz,
                      size: 28,
                      color: _kGreenPrimary,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'swap',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kGreenPrimary,
                        letterSpacing: 0.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Their side — "You get"
              Expanded(
                child: _ItemSide(
                  avatarInitial: proposal.otherUser.displayName.isNotEmpty
                      ? proposal.otherUser.displayName[0].toUpperCase()
                      : '?',
                  avatarPhotoUrl: proposal.otherUser.photoUrl,
                  label: 'You get',
                  item: proposal.theirItem,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // CO₂ estimate banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _kGreenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, size: 16, color: _kGreenDark),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kGreenDark,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Complete this swap to save ~'),
                        TextSpan(
                          text: '${co2.toStringAsFixed(1)} kg CO₂',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTAs
  // ---------------------------------------------------------------------------

  Widget _buildCtas(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary — "Send a message"
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreenPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.message_outlined, size: 18),
            label: const Text(
              'Send a message',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            onPressed: () => onSendMessage?.call(proposal.matchId),
          ),
        ),
        const SizedBox(height: 10),
        // Ghost — "Keep swiping"
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: onKeepSwiping,
          child: const Text(
            'Keep swiping',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ItemSide — one column in the trade card (avatar + label + photo + name)
// ---------------------------------------------------------------------------

class _ItemSide extends StatelessWidget {
  final String avatarInitial;
  final String? avatarPhotoUrl;
  final String label;
  final Item item;

  const _ItemSide({
    required this.avatarInitial,
    this.avatarPhotoUrl,
    required this.label,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar circle (36px)
        _AvatarCircle(
          initial: avatarInitial,
          photoUrl: avatarPhotoUrl ?? '',
          size: 36,
        ),
        const SizedBox(height: 10),
        // "You give" / "You get" label
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _kTextSecondary,
            letterSpacing: 0.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        // Item photo square
        _ItemThumb(item: item),
        const SizedBox(height: 8),
        // Item name
        Text(
          item.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ItemThumb — square item photo with fallback
// ---------------------------------------------------------------------------

class _ItemThumb extends StatelessWidget {
  final Item item;

  const _ItemThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: item.photoUrl.isNotEmpty
            ? Image.network(
                item.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, stack) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: _kSurfaceAlt,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 24, color: _kTextTertiary),
    );
  }
}

// ---------------------------------------------------------------------------
// _AvatarCircle — circular avatar with initials fallback
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  final String initial;
  final String photoUrl;
  final double size;

  const _AvatarCircle({
    required this.initial,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: photoUrl.isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context2, err, stack) => _initials(),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    return Container(
      color: _kGreenSoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: _kGreenDark,
        ),
      ),
    );
  }
}
