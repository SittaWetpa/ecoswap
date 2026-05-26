// WBS 9.6 — QR Role-Pick Modal
//
// Shown when the user taps the "Exchange" CTA in the chat header.
// Asks whether the user will display their QR or scan the other party's QR,
// then navigates to the appropriate QR screen, passing the matchId as the
// route argument.
//
// Design tokens from EcoSwap Style Guide.
// Vocabulary rule: "Swap" in UI copy, never "Trade".

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens (EcoSwap Style Guide)
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);

// ---------------------------------------------------------------------------
// Route names — consumed by both the modal and the caller for navigation
// ---------------------------------------------------------------------------

/// Named route for the QR Show screen (WBS 10.3).
const kQRShowRoute = '/qr/show';

/// Named route for the QR Scan screen (WBS 10.4).
const kQRScanRoute = '/qr/scan';

// ---------------------------------------------------------------------------
// QrRolePickModal
// ---------------------------------------------------------------------------

/// A bottom-sheet-style modal that asks the user whether they will show their
/// QR code or scan the other party's QR code.
///
/// Tapping "Show my QR" navigates to [kQRShowRoute] with [matchId] as the
/// route argument.  Tapping "Scan their QR" navigates to [kQRScanRoute]
/// with [matchId] as the route argument.  Tapping Cancel (or dismissing by
/// tapping outside the sheet) closes the modal with no navigation.
///
/// The widget uses [Navigator.of(context).pushNamed] for navigation so it
/// works with both [MaterialApp.routes] and [MaterialApp.onGenerateRoute].
/// In widget tests, inject an [onShowQR] / [onScanQR] callback to intercept
/// navigation without needing a real Navigator routes map.
class QrRolePickModal extends StatelessWidget {
  /// The match ID to pass as the route argument to the QR screens.
  final String matchId;

  /// Optional override for "Show my QR" navigation — used in widget tests.
  final VoidCallback? onShowQR;

  /// Optional override for "Scan their QR" navigation — used in widget tests.
  final VoidCallback? onScanQR;

  const QrRolePickModal({
    super.key,
    required this.matchId,
    this.onShowQR,
    this.onScanQR,
  });

  // ---------------------------------------------------------------------------
  // show() — convenience static method to display the modal as a bottom sheet
  // ---------------------------------------------------------------------------

  /// Displays the [QrRolePickModal] as a modal bottom sheet.
  ///
  /// Returns a [Future] that completes when the sheet closes.
  static Future<void> show(
    BuildContext context, {
    required String matchId,
    VoidCallback? onShowQR,
    VoidCallback? onScanQR,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Allow tapping outside to dismiss (cancel action).
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QrRolePickModal(
        matchId: matchId,
        onShowQR: onShowQR,
        onScanQR: onScanQR,
      ),
    );
  }

  void _handleShowQR(BuildContext context) {
    Navigator.of(context).pop(); // close the modal
    if (onShowQR != null) {
      onShowQR!();
    } else {
      Navigator.of(context).pushNamed(kQRShowRoute, arguments: matchId);
    }
  }

  void _handleScanQR(BuildContext context) {
    Navigator.of(context).pop(); // close the modal
    if (onScanQR != null) {
      onScanQR!();
    } else {
      Navigator.of(context).pushNamed(kQRScanRoute, arguments: matchId);
    }
  }

  void _handleCancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle bar ─────────────────────────────────────────────────
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
            // ── Title ──────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Are you with the other person right now?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                  height: 1.4,
                ),
              ),
            ),
            // ── Subtitle ───────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Text(
                'Both parties need to scan each other to complete the swap.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _kTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
            // ── Option buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _RoleOptionButton(
                icon: Icons.qr_code,
                label: "I'll show the QR",
                onPressed: () => _handleShowQR(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _RoleOptionButton(
                icon: Icons.qr_code_scanner,
                label: "I'll scan their QR",
                onPressed: () => _handleScanQR(context),
              ),
            ),
            // ── Cancel ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: TextButton(
                onPressed: () => _handleCancel(context),
                style: TextButton.styleFrom(
                  foregroundColor: _kTextSecondary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RoleOptionButton
// ---------------------------------------------------------------------------

class _RoleOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _RoleOptionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreenPrimary,
          foregroundColor: _kSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _OptionCard (alternative card-style layout — kept for reference only)
// ---------------------------------------------------------------------------

/// A tappable card used as an option in the role-pick modal.
///
/// Not used in the main build path — kept as an optional visual alternative.
class QrOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const QrOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: _kGreenPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _kTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _kTextSecondary),
          ],
        ),
      ),
    );
  }
}
