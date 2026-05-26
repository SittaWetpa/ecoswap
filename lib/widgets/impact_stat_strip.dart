/// Impact Stat Strip — WBS 11.4
///
/// A 3-stat horizontal strip rendered on the Profile screen (WBS 5.4)
/// showing the current user's denormalized impact counters:
///
///   - Swaps (integer count)
///   - kg CO₂ (one decimal place)
///   - kg waste (one decimal place)
///
/// Reads via [ImpactService.getCurrentUserImpact] — the same code path the
/// Impact Dashboard (WBS 11.3) uses, which guarantees the WBS 11.4
/// acceptance criterion "Values match what's shown on the dashboard".
///
/// Locked decisions enforced here (CLAUDE.md):
///   - NO trend arrows ("↑38%").
///   - NO "this month" comparison cards or comparison stats.
///   - User-facing label is "Swaps" (code/data may say trade).
///
/// Prototype reference: `prototype/src/screens/profile.jsx` — the
/// `SummaryStat` strip embedded in `ProfileScreen`.
library;

import 'package:flutter/material.dart';

import '../services/impact_service.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide (lifted from
// lib/screens/profile/profile_screen.dart so both surfaces stay in sync).
// ---------------------------------------------------------------------------

const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);

// ---------------------------------------------------------------------------
// SummaryStat — one stat in the strip
// ---------------------------------------------------------------------------

/// A single stat inside an [ImpactStatStrip].
///
/// Corresponds to the `SummaryStat` atom in
/// `prototype/src/screens/profile.jsx`. Renders a large bold value on top
/// and a small label underneath, both in the dark-green brand colour on
/// the green-soft container.
class SummaryStat extends StatelessWidget {
  /// Pre-formatted value string. Callers do the formatting upstream so that
  /// the dashboard and the profile strip stay consistent — see the
  /// `formatted*` getters on [UserImpact].
  final String value;

  /// Label below the value (e.g. `Swaps`, `kg CO₂`, `kg waste`).
  final String label;

  const SummaryStat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _kGreenDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kGreenDark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ImpactStatStrip — 3-stat horizontal strip
// ---------------------------------------------------------------------------

/// 3-stat horizontal impact strip for the Profile screen (WBS 11.4).
///
/// Reads the current user's impact via [ImpactService.getCurrentUserImpact].
///
/// To avoid a loading flash on a screen that already has the counters in
/// memory (the Profile screen streams `/users/{uid}` for other fields),
/// callers MAY pass an [initialImpact] which is rendered synchronously
/// while the service call resolves.
///
/// Both [impactService] and [initialImpact] are independently optional:
///   - Neither provided → uses a default [ImpactService] (production
///     Firestore) and shows a small loading placeholder until the future
///     resolves.
///   - Only [initialImpact] → renders synchronously, never calls the
///     service. Useful when the caller already has fresh counter values
///     from another stream (e.g. the Profile screen's `/users/` listener).
///   - Only [impactService] → uses the injected service. Useful in
///     widget tests.
///   - Both → renders [initialImpact] synchronously and refreshes from
///     the service in the background.
class ImpactStatStrip extends StatefulWidget {
  /// Injectable impact service. Defaults to a production instance.
  final ImpactService? impactService;

  /// Optional seed value. When provided, the strip renders these numbers
  /// immediately (no loading state). If [impactService] is also provided
  /// the strip will refresh in the background; otherwise this is the
  /// final value.
  final UserImpact? initialImpact;

  const ImpactStatStrip({super.key, this.impactService, this.initialImpact});

  @override
  State<ImpactStatStrip> createState() => _ImpactStatStripState();
}

class _ImpactStatStripState extends State<ImpactStatStrip> {
  UserImpact? _impact;

  @override
  void initState() {
    super.initState();
    _impact = widget.initialImpact;
    // Only call the service when the caller actually wired one. When the
    // strip is rendered inside a screen that already streams the user
    // doc (the Profile screen does), the seed value is the canonical
    // source and a service call would be wasted work.
    if (widget.impactService != null) {
      _refresh();
    } else if (widget.initialImpact == null) {
      // No seed, no injected service — fall back to a default service
      // so the strip still works when dropped onto a screen that
      // doesn't stream the user doc.
      _refresh();
    }
  }

  @override
  void didUpdateWidget(covariant ImpactStatStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent feeds a fresher seed value (e.g. the Profile screen's
    // `/users/` stream just emitted), reflect it immediately so the strip
    // stays in sync with the user-doc snapshot.
    if (widget.initialImpact != null &&
        widget.initialImpact != oldWidget.initialImpact) {
      setState(() => _impact = widget.initialImpact);
    }
  }

  Future<void> _refresh() async {
    final service = widget.impactService ?? ImpactService();
    try {
      final result = await service.getCurrentUserImpact();
      if (!mounted) return;
      setState(() => _impact = result);
    } catch (_) {
      // Cold-start / not-signed-in: leave the seed value (or zero) in
      // place. The Profile screen is gated by an auth guard so a thrown
      // NotSignedInException here would indicate a programming error
      // elsewhere — not something the user should see.
      if (!mounted) return;
      if (_impact == null) {
        setState(() => _impact = UserImpact.zero);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final impact = _impact;

    return Container(
      key: const Key('impactSummary'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kGreenSoft,
        borderRadius: BorderRadius.circular(12), // --radius-lg
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: impact == null
            ? const [
                // Initial frame before the future resolves. Three
                // dash placeholders preserve the strip's height so
                // the screen doesn't reflow when the data lands.
                SummaryStat(value: '—', label: 'Swaps'),
                SummaryStat(value: '—', label: 'kg CO₂'),
                SummaryStat(value: '—', label: 'kg waste'),
              ]
            : [
                SummaryStat(value: impact.formattedTrades, label: 'Swaps'),
                SummaryStat(value: impact.formattedCo2Kg, label: 'kg CO₂'),
                SummaryStat(value: impact.formattedWasteKg, label: 'kg waste'),
              ],
      ),
    );
  }
}
