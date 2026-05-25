/// Swap Confirmed Screen — WBS 10.6 (Flutter consumer side)
///
/// Shown after a successful QR scan completes a trade. The Cloud Function
/// `validateQRToken` (WBS 10.2) plus its helper `writeTradeAndImpact`
/// (WBS 10.6, server side) atomically write the `/trades/{tradeId}` document,
/// flip both items to `status: 'traded'`, and increment the three
/// denormalized counters on both `/users/{uid}` docs.
///
/// This screen reads the impact numbers **directly from the trade doc** — it
/// does NOT recompute them client-side. Recomputing here would risk drift with
/// the server's lookup tables in `functions/src/constants/impact.ts`.
///
/// The screen is reachable from two flows:
///
///   (a) The scanner client: WBS 10.4's HTTP return value carries `tradeId`.
///   (b) The presenter client: WBS 10.3's match snapshot listener fires when
///       `match.status` flips to `'completed'`, at which point the client
///       queries `/trades/` for the doc whose `matchId` matches.
///
/// Both clients land on the same screen. Each renders the gains object whose
/// `userId` matches the current uid (userAGains for A, userBGains for B).
///
/// Locked decisions enforced here:
///   - Copy: "Swap complete!" — never "Trade complete!".
///   - Title-only top bar: no cog, no info icon, no share button.
///   - No trend arrows, no "this month" comparison cards, no verified badges,
///     no activity status.
///   - Impact numbers come from the trade doc — not from
///     `lib/constants/impact.dart`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
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

// ---------------------------------------------------------------------------
// SwapConfirmedData — display-ready value object
// ---------------------------------------------------------------------------

/// All display-ready data for the Swap Confirmed screen.
///
/// Produced from a `/trades/{tradeId}` doc plus the two `/items/` docs and
/// the counterparty's `/users/` doc, or injected directly in widget tests to
/// avoid hitting Firebase.
///
/// `myCo2Saved` and `myWasteDiverted` MUST be sourced from the trade doc's
/// `impact.userAGains` or `impact.userBGains` (whichever matches the current
/// uid) — never recomputed from the items.
class SwapConfirmedData {
  /// Photo URL of the item the current user gave away.
  final String myItemPhotoUrl;

  /// Name of the item the current user gave away.
  final String myItemName;

  /// Photo URL of the item the current user received.
  final String theirItemPhotoUrl;

  /// Name of the item the current user received.
  final String theirItemName;

  /// Display name of the counterparty.
  final String counterpartyName;

  /// CO₂ saved attributed to the current user — read from the trade doc.
  ///
  /// For user A this is `impact.userAGains.co2Saved`; for user B it is
  /// `impact.userBGains.co2Saved`. Server-computed; do not recompute.
  final double myCo2Saved;

  /// Waste diverted attributed to the current user — read from the trade doc.
  ///
  /// For user A this is `impact.userAGains.wasteDiverted`; for user B it is
  /// `impact.userBGains.wasteDiverted`. Server-computed; do not recompute.
  final double myWasteDiverted;

  const SwapConfirmedData({
    required this.myItemPhotoUrl,
    required this.myItemName,
    required this.theirItemPhotoUrl,
    required this.theirItemName,
    required this.counterpartyName,
    required this.myCo2Saved,
    required this.myWasteDiverted,
  });
}

// ---------------------------------------------------------------------------
// Loader — resolves a SwapConfirmedData from a tradeId
// ---------------------------------------------------------------------------

/// Reads a `/trades/{tradeId}` doc, the two `/items/` docs, and the
/// counterparty's `/users/` doc, and produces a [SwapConfirmedData] for the
/// supplied [currentUid].
///
/// Picks `userAGains` when `currentUid == impact.userAGains.userId`, else
/// `userBGains`. If neither matches, returns null (caller should treat as
/// an error — the current user wasn't a participant in this trade).
Future<SwapConfirmedData?> loadSwapConfirmedData({
  required String tradeId,
  required String currentUid,
  FirebaseFirestore? firestore,
}) async {
  final db = firestore ?? FirebaseFirestore.instance;

  final tradeSnap = await db.collection('trades').doc(tradeId).get();
  final tradeData = tradeSnap.data();
  if (tradeData == null) return null;

  final impact = tradeData['impact'] as Map<String, dynamic>?;
  final userAGains = impact?['userAGains'] as Map<String, dynamic>?;
  final userBGains = impact?['userBGains'] as Map<String, dynamic>?;
  if (userAGains == null || userBGains == null) return null;

  final isUserA = userAGains['userId'] == currentUid;
  final isUserB = userBGains['userId'] == currentUid;
  if (!isUserA && !isUserB) return null;

  final myGains = isUserA ? userAGains : userBGains;
  final myCo2 = (myGains['co2Saved'] as num?)?.toDouble() ?? 0;
  final myWaste = (myGains['wasteDiverted'] as num?)?.toDouble() ?? 0;
  final counterpartyId = isUserA
      ? userBGains['userId'] as String? ?? ''
      : userAGains['userId'] as String? ?? '';

  // itemsExchanged.fromA is A's item now in B's hands.
  // itemsExchanged.fromB is B's item now in A's hands.
  final itemsExchanged = tradeData['itemsExchanged'] as Map<String, dynamic>?;
  final fromA = itemsExchanged?['fromA'] as String? ?? '';
  final fromB = itemsExchanged?['fromB'] as String? ?? '';

  // From the current user's perspective:
  //   myItemId    = the item I gave away
  //   theirItemId = the item I received
  final myItemId = isUserA ? fromA : fromB;
  final theirItemId = isUserA ? fromB : fromA;

  final myItemSnapF = db.collection('items').doc(myItemId).get();
  final theirItemSnapF = db.collection('items').doc(theirItemId).get();
  final counterpartySnapF = db.collection('users').doc(counterpartyId).get();

  final myItemSnap = await myItemSnapF;
  final theirItemSnap = await theirItemSnapF;
  final counterpartySnap = await counterpartySnapF;

  final myItemData = myItemSnap.data() ?? {};
  final theirItemData = theirItemSnap.data() ?? {};
  final counterpartyData = counterpartySnap.data() ?? {};

  return SwapConfirmedData(
    myItemPhotoUrl: myItemData['photoUrl'] as String? ?? '',
    myItemName: myItemData['name'] as String? ?? '',
    theirItemPhotoUrl: theirItemData['photoUrl'] as String? ?? '',
    theirItemName: theirItemData['name'] as String? ?? '',
    counterpartyName: counterpartyData['displayName'] as String? ?? '',
    myCo2Saved: myCo2,
    myWasteDiverted: myWaste,
  );
}

// ---------------------------------------------------------------------------
// SwapConfirmedScreen — WBS 10.6 Flutter UI
// ---------------------------------------------------------------------------

/// Injectable getter for the current user's uid — defaulted to
/// FirebaseAuth.instance.currentUser?.uid so widget tests can stub it.
typedef CurrentUidGetter = String? Function();

String? _defaultUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

/// Swap Confirmed screen. Shows both items, both photos, "Swap complete!"
/// headline, and personal impact numbers read from the trade doc.
///
/// Three ways to provide data:
///
///   1. Inject [data] directly (used by widget tests and by the scanner
///      client which already has the data resolved).
///   2. Provide [tradeId] — the screen resolves the data from Firestore via
///      [loadSwapConfirmedData] using [getCurrentUid] for attribution.
///   3. Provide neither — renders an error state. This shouldn't happen in
///      production; it's a defensive fallback.
class SwapConfirmedScreen extends StatefulWidget {
  /// When non-null, used directly. Bypasses Firestore.
  final SwapConfirmedData? data;

  /// When non-null and [data] is null, used to load the data from Firestore.
  final String? tradeId;

  /// Injectable uid getter — defaults to FirebaseAuth.
  final CurrentUidGetter? getCurrentUid;

  /// Injectable Firestore handle (test seam).
  final FirebaseFirestore? firestore;

  /// Called when the user taps "See my impact". When null, no-op.
  final VoidCallback? onSeeImpact;

  /// Called when the user taps "Back to chats". When null, no-op.
  final VoidCallback? onBackToChats;

  const SwapConfirmedScreen({
    super.key,
    this.data,
    this.tradeId,
    this.getCurrentUid,
    this.firestore,
    this.onSeeImpact,
    this.onBackToChats,
  });

  @override
  State<SwapConfirmedScreen> createState() => _SwapConfirmedScreenState();
}

class _SwapConfirmedScreenState extends State<SwapConfirmedScreen> {
  Future<SwapConfirmedData?>? _loader;

  @override
  void initState() {
    super.initState();
    if (widget.data == null && widget.tradeId != null) {
      final uid = (widget.getCurrentUid ?? _defaultUidGetter)();
      if (uid != null && uid.isNotEmpty) {
        _loader = loadSwapConfirmedData(
          tradeId: widget.tradeId!,
          currentUid: uid,
          firestore: widget.firestore,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Path 1: explicit data injected.
    if (widget.data != null) {
      return _buildScaffold(_buildContent(widget.data!));
    }

    // Path 2: load from Firestore.
    if (_loader != null) {
      return _buildScaffold(
        FutureBuilder<SwapConfirmedData?>(
          future: _loader,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _buildErrorContent();
            }
            return _buildContent(snapshot.data!);
          },
        ),
      );
    }

    // Path 3: no inputs — error state.
    return _buildScaffold(_buildErrorContent());
  }

  Widget _buildScaffold(Widget body) {
    // Title-only top bar — no cog, no info icon, no share icon.
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'Swap',
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
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildErrorContent() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          "We couldn't load this swap. Please check Chats for the trade record.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _kTextSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(SwapConfirmedData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Success check circle ─────────────────────────────────────
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: _kGreenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 44,
                color: _kGreenPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Headline ─────────────────────────────────────────────────
          // Locked copy: "Swap complete!" — never "Trade complete!".
          const Center(
            child: Text(
              'Swap complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // ── Subline ──────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                "Your ${data.myItemName} for ${data.counterpartyName}'s ${data.theirItemName}.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _kTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ── Both item photos ─────────────────────────────────────────
          _ItemPair(
            myItemPhotoUrl: data.myItemPhotoUrl,
            myItemName: data.myItemName,
            theirItemPhotoUrl: data.theirItemPhotoUrl,
            theirItemName: data.theirItemName,
          ),
          const SizedBox(height: 28),
          // ── Impact stat cards ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ImpactCard(
                  label: 'CO₂ saved',
                  value: '+${_formatKg(data.myCo2Saved)} kg',
                  highlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImpactCard(
                  label: 'Waste diverted',
                  value: '+${_formatKg(data.myWasteDiverted)} kg',
                  highlight: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Added to your impact dashboard.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextTertiary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // ── CTAs ─────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: widget.onSeeImpact,
            icon: const Icon(Icons.eco_outlined, size: 18),
            label: const Text(
              'See my impact',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreenPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onBackToChats,
            style: TextButton.styleFrom(
              foregroundColor: _kTextSecondary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text(
              'Back to chats',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a CO₂/waste value for display. Always one decimal place, matching
/// the prototype's `.toFixed(1)`.
String _formatKg(double value) {
  if (value.isNaN || value.isInfinite) return '0.0';
  return value.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------
// _ItemPair — side-by-side photos and names of the two swapped items
// ---------------------------------------------------------------------------

class _ItemPair extends StatelessWidget {
  final String myItemPhotoUrl;
  final String myItemName;
  final String theirItemPhotoUrl;
  final String theirItemName;

  const _ItemPair({
    required this.myItemPhotoUrl,
    required this.myItemName,
    required this.theirItemPhotoUrl,
    required this.theirItemName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ItemTile(
            photoUrl: myItemPhotoUrl,
            name: myItemName,
            label: 'You gave',
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 56),
          child: Icon(
            Icons.swap_horiz_rounded,
            size: 20,
            color: _kGreenPrimary,
          ),
        ),
        Expanded(
          child: _ItemTile(
            photoUrl: theirItemPhotoUrl,
            name: theirItemName,
            label: 'You received',
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String photoUrl;
  final String name;
  final String label;

  const _ItemTile({
    required this.photoUrl,
    required this.name,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _kTextSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: _kSurfaceAlt,
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const _ItemPhotoFallback(),
                    )
                  : const _ItemPhotoFallback(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ItemPhotoFallback extends StatelessWidget {
  const _ItemPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_outlined, size: 24, color: _kTextTertiary),
    );
  }
}

// ---------------------------------------------------------------------------
// _ImpactCard — one stat tile (CO₂ saved / Waste diverted)
// ---------------------------------------------------------------------------

class _ImpactCard extends StatelessWidget {
  final String label;
  final String value;

  /// When true, uses the green-soft surface and green-dark text (for the
  /// CO₂ card). When false, uses the neutral surface (for the waste card).
  final bool highlight;

  const _ImpactCard({
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = highlight ? _kGreenSoft : _kSurfaceAlt;
    final labelColor = highlight ? _kGreenDark : _kTextSecondary;
    final valueColor = highlight ? _kGreenDark : _kTextPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: labelColor,
              height: 1.3,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
