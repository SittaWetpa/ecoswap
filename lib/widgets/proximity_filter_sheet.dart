/// Proximity Filter Bottom Sheet — WBS 7.4
///
/// Shows 4 proximity options; the selected option is persisted in
/// [SharedPreferences] under the key [ProximityFilterSheet.prefKey].
///
/// Usage:
/// ```dart
/// await ProximityFilterSheet.show(
///   context,
///   current: bucket,
///   onChanged: (newBucket) { /* reload feed */ },
/// );
/// ```
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Enum
// ---------------------------------------------------------------------------

/// The four proximity buckets.  Ordered from most-local (index 0) to
/// least-local (index 3) so that comparisons like
/// `bucket.index <= maxBucket.index` work naturally (WBS 7.2).
enum ProximityBucket {
  sameDistrict,
  sameProvince,
  nearbyProvinces,
  allThailand,
}

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

/// Reads the persisted [ProximityBucket] from [SharedPreferences].
/// Returns [ProximityBucket.sameProvince] if no value is stored (WBS 7.4:
/// "The default is `same_province`").
Future<ProximityBucket> loadProximityBucket() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(ProximityFilterSheet.prefKey);
  return _bucketFromKey(raw) ?? ProximityBucket.sameProvince;
}

/// Persists [bucket] to [SharedPreferences] under [ProximityFilterSheet.prefKey].
Future<void> saveProximityBucket(ProximityBucket bucket) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(ProximityFilterSheet.prefKey, _keyFromBucket(bucket));
}

ProximityBucket? _bucketFromKey(String? key) {
  switch (key) {
    case 'district':
      return ProximityBucket.sameDistrict;
    case 'province':
      return ProximityBucket.sameProvince;
    case 'nearby':
      return ProximityBucket.nearbyProvinces;
    case 'thailand':
      return ProximityBucket.allThailand;
    default:
      return null;
  }
}

String _keyFromBucket(ProximityBucket bucket) {
  switch (bucket) {
    case ProximityBucket.sameDistrict:
      return 'district';
    case ProximityBucket.sameProvince:
      return 'province';
    case ProximityBucket.nearbyProvinces:
      return 'nearby';
    case ProximityBucket.allThailand:
      return 'thailand';
  }
}

// ---------------------------------------------------------------------------
// Option metadata
// ---------------------------------------------------------------------------

/// Metadata for a single proximity option row.
class ProximityOption {
  final ProximityBucket bucket;
  final String label;
  final String sub;

  const ProximityOption({
    required this.bucket,
    required this.label,
    required this.sub,
  });
}

/// The 4 options, in order from most-local to least-local.
/// Exactly 4, no more (WBS 7.4: "4 options exactly, no more").
const List<ProximityOption> kProximityOptions = [
  ProximityOption(
    bucket: ProximityBucket.sameDistrict,
    label: 'Same district',
    sub: 'Your district only',
  ),
  ProximityOption(
    bucket: ProximityBucket.sameProvince,
    label: 'Same province',
    sub: 'Your province area',
  ),
  ProximityOption(
    bucket: ProximityBucket.nearbyProvinces,
    label: 'Nearby provinces',
    sub: 'Your province + surrounding provinces',
  ),
  ProximityOption(
    bucket: ProximityBucket.allThailand,
    label: 'All Thailand',
    sub: 'Show everyone',
  ),
];

/// Returns the human-readable label for a [ProximityBucket].
String proximityLabel(ProximityBucket bucket) {
  return kProximityOptions
      .firstWhere((o) => o.bucket == bucket)
      .label;
}

// ---------------------------------------------------------------------------
// Design tokens (matching EcoSwap Style Guide)
// ---------------------------------------------------------------------------

const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Bottom sheet for selecting the proximity filter.
///
/// - Shows exactly 4 options (WBS 7.4).
/// - Selected row is highlighted with [_kGreenSoft] background.
/// - Tapping an option persists it and calls [onChanged].
class ProximityFilterSheet extends StatelessWidget {
  /// The [SharedPreferences] key used to persist the selected bucket.
  static const String prefKey = 'proximity_filter';

  /// Currently selected bucket.
  final ProximityBucket current;

  /// Called when the user picks a new bucket (or re-selects the same one).
  /// The caller is responsible for dismissing the sheet and reloading the feed.
  final ValueChanged<ProximityBucket> onChanged;

  const ProximityFilterSheet({
    super.key,
    required this.current,
    required this.onChanged,
  });

  /// Convenience method — shows the sheet as a modal bottom sheet.
  ///
  /// Returns the newly selected [ProximityBucket], or null if the user
  /// dismissed without selecting.
  static Future<ProximityBucket?> show(
    BuildContext context, {
    required ProximityBucket current,
    required ValueChanged<ProximityBucket> onChanged,
  }) {
    return showModalBottomSheet<ProximityBucket>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProximityFilterSheet(
        current: current,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000), // shadow-modal
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      // SingleChildScrollView allows the sheet to shrink-wrap on large screens
      // and scroll gracefully on small/test viewports without overflow errors.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildOptionsList(context),
            // Safe area bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Show me swappers in…',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wider ranges show more people but less local matches.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _kTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Close button — icon-only, 40x40 tap target
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.close, size: 20, color: _kTextSecondary),
              padding: EdgeInsets.zero,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: kProximityOptions.map((opt) {
          return _OptionRow(
            option: opt,
            selected: opt.bucket == current,
            onTap: () {
              saveProximityBucket(opt.bucket);
              onChanged(opt.bucket);
              Navigator.of(context).pop();
            },
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private: individual option row
// ---------------------------------------------------------------------------

class _OptionRow extends StatelessWidget {
  final ProximityOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? _kGreenSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _kTextPrimary,
                      height: 1.4,
                    ),
                  ),
                  Text(
                    option.sub,
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
            if (selected)
              const Icon(Icons.check, size: 20, color: _kGreenDark),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pill widget — the tappable chip shown in the Discover top bar
// ---------------------------------------------------------------------------

/// A tappable green pill that shows the current [ProximityBucket] label.
///
/// Tapping it calls [onTap] — the parent (DiscoverScreen) opens
/// [ProximityFilterSheet] in response.
class ProximityPill extends StatelessWidget {
  final ProximityBucket bucket;
  final VoidCallback onTap;

  const ProximityPill({
    super.key,
    required this.bucket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kGreenSoft,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 12, color: _kGreenDark),
            const SizedBox(width: 4),
            Text(
              proximityLabel(bucket),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _kGreenDark,
                height: 1.3,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 12, color: _kGreenDark),
          ],
        ),
      ),
    );
  }
}
