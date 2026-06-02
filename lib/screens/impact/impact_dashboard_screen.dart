/// Impact Dashboard Screen — WBS 11.3
///
/// Top-level Impact screen. Single hero CO₂ number, two metric cards
/// (swaps completed + waste diverted), and the latest 10 trades involving
/// the current user, ordered by `completedAt` descending.
///
/// Locked decisions enforced here (CLAUDE.md):
///   - Title-only top bar — no cog, no info icon, no share button.
///   - NO trend arrows ("↑38%").
///   - NO "This month" comparison card or comparison stats.
///   - Counter values are read from the denormalized `/users/{uid}` fields
///     via [ImpactService] (WBS 11.2). The dashboard NEVER recomputes CO₂
///     client-side — the 10.6 Cloud Function transaction is the single
///     writer of the counters and of `/trades/`.
///
/// Prototype reference: `prototype/src/screens/impact.jsx`, dashboard
/// variant only. Variants B (timeline) and C (compare) are design
/// exploration and are NOT implemented.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../services/impact_service.dart';

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

// ---------------------------------------------------------------------------
// TradeRowData — display-ready data for a single recent trade
// ---------------------------------------------------------------------------

/// Display-ready data for one row in the Recent swaps list.
///
/// Produced from a `/trades/{tradeId}` doc (plus the two `/items/` and the
/// counterparty `/users/` docs), or injected directly in widget tests to
/// avoid hitting Firebase.
///
/// `myCo2Saved` is the current user's CO₂ contribution from this single
/// trade — read from `impact.userAGains.co2Saved` or
/// `impact.userBGains.co2Saved` (whichever matches the current uid). Server
/// computed; never recomputed client-side.
class TradeRowData {
  final String tradeId;
  final String counterpartyName;
  final String counterpartyPhotoUrl;
  final String myItemName;
  final String theirItemName;
  final double myCo2Saved;
  final DateTime? completedAt;

  const TradeRowData({
    required this.tradeId,
    required this.counterpartyName,
    required this.counterpartyPhotoUrl,
    required this.myItemName,
    required this.theirItemName,
    required this.myCo2Saved,
    this.completedAt,
  });
}

// ---------------------------------------------------------------------------
// Default UID getter
// ---------------------------------------------------------------------------

typedef CurrentUidGetter = String? Function();

String? _defaultUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// Date formatter — short "May 26" form for the trade row
// ---------------------------------------------------------------------------

String _formatTradeDate(DateTime? time) {
  if (time == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[time.month - 1]} ${time.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// ImpactDashboardScreen — WBS 11.3
// ---------------------------------------------------------------------------

/// Impact Dashboard screen.
///
/// Reads the three denormalized counters from `/users/{uid}` via
/// [ImpactService.getCurrentUserImpact] (WBS 11.2) and the latest 10
/// `/trades/` involving the current user.
///
/// All dependencies are injectable for widget tests:
///   - [impactService] — fake [ImpactService] returning a fixed
///     [UserImpact] without touching Firestore.
///   - [tradesStream] — fake stream of resolved [TradeRowData] for the
///     recent swaps list.
///   - [getCurrentUid] — fixed uid getter for tests.
class ImpactDashboardScreen extends StatelessWidget {
  /// Injectable impact service. Defaults to a production instance.
  final ImpactService? impactService;

  /// Optional stream override — used in tests to inject fake trade rows
  /// without needing a real Firestore. When null, the screen builds a
  /// Firestore stream filtered to the current user.
  final Stream<List<TradeRowData>>? tradesStream;

  /// Injectable UID getter — defaults to
  /// [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  /// Called when the user taps a trade row. When null, taps are no-ops.
  final void Function(TradeRowData row)? onTradeTap;

  const ImpactDashboardScreen({
    super.key,
    this.impactService,
    this.tradesStream,
    this.getCurrentUid,
    this.onTradeTap,
  });

  ImpactService get _service => impactService ?? ImpactService();
  CurrentUidGetter get _uidGetter => getCurrentUid ?? _defaultUidGetter;

  // Builds a live stream of resolved trade rows from Firestore.
  //
  // The dashboard wants "trades involving the current user, latest 10 by
  // completedAt desc". `/trades/` doesn't carry a participants array, so we
  // run two queries (one against `impact.userAGains.userId`, one against
  // `impact.userBGains.userId`) and merge their results client-side. Each
  // query is independently limited to 10 — that's the worst case for the
  // merge.
  Stream<List<TradeRowData>> _buildFirestoreStream(String uid) {
    final db = FirebaseFirestore.instance;
    final asAStream = db
        .collection('trades')
        .where('impact.userAGains.userId', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .limit(10)
        .snapshots();
    final asBStream = db
        .collection('trades')
        .where('impact.userBGains.userId', isEqualTo: uid)
        .orderBy('completedAt', descending: true)
        .limit(10)
        .snapshots();

    // Combine the two snapshots into a single merged-and-sorted list.
    // We use a small controller-style helper: re-emit whenever either side
    // updates, taking the latest snapshot from the other side.
    QuerySnapshot<Map<String, dynamic>>? lastA;
    QuerySnapshot<Map<String, dynamic>>? lastB;
    late final StreamController<List<TradeRowData>> ctrl;
    void emit() async {
      if (lastA == null && lastB == null) return;
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...?lastA?.docs,
        ...?lastB?.docs,
      ];
      try {
        final rows = await Future.wait(
          docs.map((d) => _resolveTradeRow(d, uid)),
        );
        rows.sort((x, y) {
          final ax = x.completedAt;
          final ay = y.completedAt;
          if (ax == null && ay == null) return 0;
          if (ax == null) return 1;
          if (ay == null) return -1;
          return ay.compareTo(ax);
        });
        if (!ctrl.isClosed) ctrl.add(rows.take(10).toList());
      } catch (e, st) {
        // Resolving an item/user doc failed — surface it instead of spinning.
        if (!ctrl.isClosed) ctrl.addError(e, st);
      }
    }

    final subs = <StreamSubscription>[];
    ctrl = StreamController<List<TradeRowData>>(
      onListen: () {
        // Forward source-query errors (e.g. a missing composite index) to the
        // controller. Without this, an errored query leaves the StreamBuilder
        // stuck on its loading spinner forever — it never sees the error.
        subs.add(
          asAStream.listen(
            (s) {
              lastA = s;
              emit();
            },
            onError: (Object e, StackTrace st) {
              if (!ctrl.isClosed) ctrl.addError(e, st);
            },
          ),
        );
        subs.add(
          asBStream.listen(
            (s) {
              lastB = s;
              emit();
            },
            onError: (Object e, StackTrace st) {
              if (!ctrl.isClosed) ctrl.addError(e, st);
            },
          ),
        );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
      },
    );
    return ctrl.stream;
  }

  // Resolves a single /trades/ doc into a [TradeRowData] using the current
  // user's perspective to pick the right "gains" object, the right item
  // names, and the counterparty's display name.
  Future<TradeRowData> _resolveTradeRow(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) async {
    final data = doc.data();
    final impact = data['impact'] as Map<String, dynamic>?;
    final userAGains = impact?['userAGains'] as Map<String, dynamic>?;
    final userBGains = impact?['userBGains'] as Map<String, dynamic>?;

    final isUserA = (userAGains?['userId'] as String?) == uid;
    final myGains = isUserA ? userAGains : userBGains;
    final myCo2 = (myGains?['co2Saved'] as num?)?.toDouble() ?? 0;

    final counterpartyId = isUserA
        ? (userBGains?['userId'] as String? ?? '')
        : (userAGains?['userId'] as String? ?? '');

    final itemsExchanged = data['itemsExchanged'] as Map<String, dynamic>?;
    final fromA = itemsExchanged?['fromA'] as String? ?? '';
    final fromB = itemsExchanged?['fromB'] as String? ?? '';
    final myItemId = isUserA ? fromA : fromB;
    final theirItemId = isUserA ? fromB : fromA;

    final db = FirebaseFirestore.instance;
    final myItemSnapF = db.collection('items').doc(myItemId).get();
    final theirItemSnapF = db.collection('items').doc(theirItemId).get();
    final counterpartySnapF = db.collection('users').doc(counterpartyId).get();

    final myItemSnap = await myItemSnapF;
    final theirItemSnap = await theirItemSnapF;
    final counterpartySnap = await counterpartySnapF;

    final completedAt = data['completedAt'];
    DateTime? completed;
    if (completedAt is Timestamp) completed = completedAt.toDate();

    return TradeRowData(
      tradeId: doc.id,
      counterpartyName:
          counterpartySnap.data()?['displayName'] as String? ?? '',
      counterpartyPhotoUrl:
          counterpartySnap.data()?['photoUrl'] as String? ?? '',
      myItemName: myItemSnap.data()?['name'] as String? ?? '',
      theirItemName: theirItemSnap.data()?['name'] as String? ?? '',
      myCo2Saved: myCo2,
      completedAt: completed,
    );
  }

  Stream<List<TradeRowData>> _resolveTradesStream(String uid) {
    if (tradesStream != null) return tradesStream!;
    return _buildFirestoreStream(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uidGetter();

    return Scaffold(
      backgroundColor: _kSurface,
      // Title-only top bar — no cog, no info icon. Locked decision.
      appBar: AppBar(
        title: const Text(
          'Impact',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: _kSurface,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(uid),
    );
  }

  Widget _buildBody(String? uid) {
    if (uid == null || uid.isEmpty) {
      return const Center(
        child: Text(
          'Sign in to see your impact.',
          style: TextStyle(color: _kTextSecondary),
        ),
      );
    }

    // Live stream (not a one-shot read) so the hero number + metric cards
    // update the moment the 10.6 transaction increments the counters after a
    // completed trade — no app refresh required.
    return StreamBuilder<UserImpact>(
      key: const Key('impact_counters_stream'),
      stream: _service.watchCurrentUserImpact(),
      builder: (context, impactSnap) {
        if (impactSnap.connectionState == ConnectionState.waiting &&
            !impactSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (impactSnap.hasError) {
          return const Center(
            child: Text(
              'Something went wrong. Please try again.',
              style: TextStyle(color: _kTextSecondary),
            ),
          );
        }

        final impact = impactSnap.data ?? UserImpact.zero;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero number — single CO₂ stat surface.
              HeroCo2Number(co2Kg: impact.co2Kg, swaps: impact.trades),
              const SizedBox(height: 8),
              // Two metric cards.
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      key: const Key('metric_card_swaps'),
                      icon: Icons.swap_horiz,
                      value: impact.formattedTrades,
                      unit: '',
                      label: 'Swaps completed',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      key: const Key('metric_card_waste'),
                      icon: Icons.delete_outline,
                      value: impact.formattedWasteKg,
                      unit: 'kg',
                      label: 'Waste diverted',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Recent swaps section header
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Recent swaps',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              _buildTradesList(uid),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTradesList(String uid) {
    return StreamBuilder<List<TradeRowData>>(
      key: const Key('recent_trades_stream'),
      stream: _resolveTradesStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Could not load recent swaps.',
              style: TextStyle(color: _kTextSecondary),
            ),
          );
        }
        final rows = snapshot.data ?? const <TradeRowData>[];
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No swaps yet — your first one will show up here.',
              style: TextStyle(color: _kTextSecondary, fontSize: 13),
            ),
          );
        }
        return Column(
          children: [
            for (final row in rows) ...[
              TradeRow(row: row, onTap: () => onTradeTap?.call(row)),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// HeroCo2Number — single hero number at the top of the dashboard
// ---------------------------------------------------------------------------

/// Display widget for the hero CO₂ number.
///
/// Mirrors the prototype's "CO₂ kept out of new production" hero. The
/// `co2Kg` value is sourced from `/users/{uid}.totalCo2Saved` (via
/// [ImpactService]); it is NEVER recomputed on the client.
class HeroCo2Number extends StatelessWidget {
  final double co2Kg;
  final int swaps;

  const HeroCo2Number({super.key, required this.co2Kg, required this.swaps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(
        children: [
          const Text(
            'CO₂ kept out of new production',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Hero number — Style Guide `display` size, green-primary colour.
          RichText(
            key: const Key('hero_co2_number'),
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: co2Kg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: _kGreenPrimary,
                    letterSpacing: -2.5,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' kg',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: _kTextSecondary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Footnote: NOT a comparison or trend, just describes the math.
          // Locked decision: NO "this month", NO trend arrows.
          Text(
            '$swaps ${swaps == 1 ? 'swap' : 'swaps'} · weight × category CO₂ factor',
            style: const TextStyle(
              fontSize: 12,
              // _kTextSecondary (≈5.2:1 on white) instead of _kTextTertiary
              // (#A0A0A0 ≈ 2.63:1) so the footnote clears WCAG AA contrast.
              color: _kTextSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MetricCard — one of the two supporting stat cards
// ---------------------------------------------------------------------------

/// One of the two supporting metric cards under the hero number.
///
/// Mirrors the prototype's `MetricCard` atom. Used for swaps completed and
/// waste diverted only. No third card, no trend arrow, no "this month".
class MetricCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kGreenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _kGreenDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kGreenDark,
                    letterSpacing: 0.4,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                    height: 1,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                      height: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TradeRow — one row in the Recent swaps list
// ---------------------------------------------------------------------------

/// One row in the Recent swaps list.
///
/// Shows the counterparty avatar, both item names with a swap arrow between
/// them, the trade date, and the current user's CO₂ contribution from this
/// specific trade.
class TradeRow extends StatelessWidget {
  final TradeRowData row;
  final VoidCallback? onTap;

  const TradeRow({super.key, required this.row, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _AvatarCircle(
              name: row.counterpartyName,
              photoUrl: row.counterpartyPhotoUrl,
              size: 36,
            ),
            const SizedBox(width: 12),
            // Items + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          row.myItemName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kTextPrimary,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.swap_horiz,
                        size: 12,
                        color: _kGreenPrimary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          row.theirItemName,
                          style: const TextStyle(
                            fontSize: 13,
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
                  const SizedBox(height: 2),
                  Text(
                    '${_formatTradeDate(row.completedAt)} · with ${row.counterpartyName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _kTextSecondary,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${row.myCo2Saved.toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kGreenPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AvatarCircle — small circular avatar used in TradeRow
// ---------------------------------------------------------------------------

class _AvatarCircle extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;

  const _AvatarCircle({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsFallback(),
        ),
      );
    }
    return _initialsFallback();
  }

  Widget _initialsFallback() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _kGreenSoft,
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: _kGreenDark,
        ),
      ),
    );
  }
}
