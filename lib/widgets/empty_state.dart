/// EmptyState widget — WBS 7.6
///
/// Reusable empty-state component used across screens.
/// Follows Style Guide §10:
///   - Center-aligned, full screen below top bar
///   - Small icon (40px, --text-tertiary)
///   - Headline in h3 (16px / 600)
///   - Description in body (15px / 400), --text-secondary, max 2 lines
///   - Optional CTA primary button below
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// EmptyState widget
// ---------------------------------------------------------------------------

/// A reusable empty-state panel used across screens when a list or feed
/// returns no results.
///
/// Layout (Style Guide §10):
/// - Centered vertically and horizontally
/// - Icon (40px, [_kTextTertiary]) at the top
/// - [headline] in h3 style (16px / 600)
/// - [description] in body style (15px / 400, [_kTextSecondary]), max 2 lines
/// - Optional primary CTA button ([ctaLabel] + [onCta])
///
/// Per-screen copy is specified in Style Guide §10. Callers pass in the
/// correct icon, headline, description, and CTA for their screen.
///
/// Example — Discover (no users in range):
/// ```dart
/// EmptyState(
///   icon: const Icon(Icons.explore_outlined, size: 40),
///   headline: 'No one nearby yet',
///   description: 'Try widening your proximity filter, or check back later —'
///       ' new swappers join every day.',
///   ctaLabel: 'Widen search',
///   onCta: () => ProximityFilterSheet.show(...),
/// )
/// ```
class EmptyState extends StatelessWidget {
  /// Icon displayed at the top of the panel (40px, [_kTextTertiary] colour).
  /// Pass an [Icon] widget with `size: 40` — the colour is overridden here.
  final Icon icon;

  /// Short headline, Style Guide h3 (16px / 600).
  final String headline;

  /// Supporting text, Style Guide body (15px / 400, [_kTextSecondary]).
  final String description;

  /// Label for the optional CTA button. When null, no button is shown.
  final String? ctaLabel;

  /// Called when the CTA button is tapped. When null (and [ctaLabel] is
  /// non-null), the button is rendered disabled.
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.headline,
    required this.description,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon — size forced to 40, colour to --text-tertiary.
            Icon(icon.icon, size: 40, color: _kTextTertiary),
            const SizedBox(height: 16),

            // Headline — h3: 16px / 600
            Text(
              headline,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description — body: 15px / 400, secondary colour
            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // CTA button (optional)
            if (ctaLabel != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('empty_state_cta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreenPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onCta,
                  child: Text(
                    ctaLabel!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
