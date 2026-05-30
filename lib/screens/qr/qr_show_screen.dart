/// QR Show Screen — WBS 10.3
///
/// Calls the `issueQRToken` Cloud Function on mount and silently refreshes
/// every 30 seconds. Renders the returned JWT as a QR code using `qr_flutter`.
/// Shows a "New code in {30→0}s" countdown that tracks the refresh cycle: it
/// hits zero exactly as the QR rotates, then resets to 30. (Each token is
/// valid for 60s server-side — the 30s refresh keeps a comfortable margin —
/// but the live counter reflects the *visible* rotation, not the raw expiry,
/// so it never contradicts itself.) Listens to `/matches/{matchId}` for
/// `status: 'completed'` and navigates to the Swap Confirmed screen when it
/// fires. Cancel returns to the previous screen (chat).
///
/// Injectable seams (for widget tests):
///   [tokenFetcher]    — replaces the Cloud Function call
///   [matchStream]     — replaces the Firestore listener
///
/// Locked decisions:
///   - Top bar: "Confirm exchange" title, back arrow only (hierarchical).
///   - Cancel returns to chat via [Navigator.pop].
///   - Swap Confirmed route: '/qr/confirmed', or [onComplete] callback
///     when injected (for tests).
///   - No GPS, no distance, no verification badge.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../widgets/qr_role_pick_modal.dart' show kQRConfirmedRoute;

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kWarning = Color(0xFFBA7517);
const _kWarningBg = Color(0xFFFFF1DD);

// ---------------------------------------------------------------------------
// Injectable typedef
// ---------------------------------------------------------------------------

/// Returns `{ 'token': String, 'expiresAt': int }` or throws.
typedef TokenFetcher = Future<Map<String, dynamic>> Function(String matchId);

/// A stream of match status strings (e.g., 'active', 'completed').
typedef MatchStreamFactory = Stream<String?> Function(String matchId);

/// Resolves the `/trades/{tradeId}` document id for a completed [matchId].
///
/// The displayer detects completion via the match-status listener and never
/// receives a tradeId directly, so it looks the trade up by matchId. Returns
/// null when no trade is found.
typedef TradeIdResolver = Future<String?> Function(String matchId);

// ---------------------------------------------------------------------------
// Production implementations
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> _defaultTokenFetcher(String matchId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('issueQRToken');
  final result = await callable.call<Map<dynamic, dynamic>>({
    'matchId': matchId,
  });
  final data = Map<String, dynamic>.from(result.data);
  return data;
}

Stream<String?> _defaultMatchStream(String matchId) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .snapshots()
      .map((snap) => snap.data()?['status'] as String?);
}

Future<String?> _defaultTradeIdResolver(String matchId) async {
  final snap = await FirebaseFirestore.instance
      .collection('trades')
      .where('matchId', isEqualTo: matchId)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  return snap.docs.first.id;
}

// ---------------------------------------------------------------------------
// QrShowScreen
// ---------------------------------------------------------------------------

/// QR Show screen — displays the current user's QR code and a countdown.
///
/// [matchId] is passed as a route argument:
///   `Navigator.pushNamed(context, '/qr/show', arguments: matchId)`
///
/// In tests, inject [tokenFetcher], [matchStream], and [onComplete] so the
/// screen never touches Firebase.
class QrShowScreen extends StatefulWidget {
  /// Called when the match completes (status → 'completed'), with the resolved
  /// tradeId (null if it couldn't be looked up).
  ///
  /// When null, navigates to [kQRConfirmedRoute] with the tradeId as the
  /// argument. Injected in tests to assert the resolved tradeId without
  /// driving a real route transition.
  final void Function(String? tradeId)? onComplete;

  /// Injectable Cloud Function replacement (for tests).
  final TokenFetcher? tokenFetcher;

  /// Injectable Firestore stream replacement (for tests).
  final MatchStreamFactory? matchStream;

  /// Injectable trade-id resolver (for tests). Defaults to a Firestore query
  /// on `/trades` by matchId.
  final TradeIdResolver? tradeIdResolver;

  /// Swap partner's display name — shown in the trade summary strip and in the
  /// instruction copy ("Show this to {partnerName}").
  final String? partnerName;

  /// Partner's photo URL for the avatar in the trade summary strip.
  final String? partnerPhotoUrl;

  /// Name of the item the current user is giving away.
  final String? myItemName;

  /// Name of the item the current user is receiving.
  final String? theirItemName;

  const QrShowScreen({
    super.key,
    this.onComplete,
    this.tokenFetcher,
    this.matchStream,
    this.tradeIdResolver,
    this.partnerName,
    this.partnerPhotoUrl,
    this.myItemName,
    this.theirItemName,
  });

  @override
  State<QrShowScreen> createState() => _QrShowScreenState();
}

class _QrShowScreenState extends State<QrShowScreen>
    with SingleTickerProviderStateMixin {
  // ── Match ID ──────────────────────────────────────────────────────────────
  late final String _matchId;

  // ── Token state ───────────────────────────────────────────────────────────
  String? _token; // null = loading / error
  bool _tokenError = false;

  // ── Countdown ─────────────────────────────────────────────────────────────
  // Tracks the 30s refresh cycle, not the 60s token expiry: counts 30 → 0 and
  // resets to 30 each time a fresh token is fetched, so the number hitting zero
  // lines up with the QR visibly rotating.
  static const int _refreshSeconds = 30;
  int _seconds = _refreshSeconds;
  Timer? _countdownTimer;

  // ── Refresh cycle ─────────────────────────────────────────────────────────
  Timer? _refreshTimer;

  // ── Firestore listener ────────────────────────────────────────────────────
  StreamSubscription<String?>? _matchSub;

  // ── Pulse animation for danger countdown ──────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read matchId from route arguments. This is safe to call here (before any
    // async work) because didChangeDependencies is called before the first build.
    if (!_initialized) {
      _matchId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      _initialized = true;
      _startSession();
    }
  }

  bool _initialized = false;

  // ── Session setup ─────────────────────────────────────────────────────────

  void _startSession() {
    _fetchToken(); // initial fetch
    // Refresh every 30 s
    _refreshTimer = Timer.periodic(const Duration(seconds: _refreshSeconds), (
      _,
    ) {
      _fetchToken();
    });
    _startCountdown();
    _subscribeToMatch();
  }

  Future<void> _fetchToken() async {
    if (!mounted) return;
    final fetcher = widget.tokenFetcher ?? _defaultTokenFetcher;
    try {
      final result = await fetcher(_matchId);
      if (!mounted) return;
      setState(() {
        _token = result['token'] as String?;
        _tokenError = _token == null || _token!.isEmpty;
        // Reset countdown to the full refresh interval on each fresh token.
        _seconds = _refreshSeconds;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tokenError = true);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        }
        // The 30s refresh resets _seconds back to 30 on each fresh token.
      });
    });
  }

  void _subscribeToMatch() {
    final factory = widget.matchStream ?? _defaultMatchStream;
    _matchSub = factory(_matchId).listen((status) {
      if (!mounted) return;
      if (status == 'completed') {
        _onMatchCompleted();
      }
    });
  }

  Future<void> _onMatchCompleted() async {
    // The displayer only learns of completion via the match-status listener and
    // never receives a tradeId, so resolve it from the matchId. The trade write
    // and the status flip happen in the same transaction (WBS 10.2), so the
    // trade doc exists by the time we get here. A null result falls through to
    // the Swap Confirmed screen's graceful error state.
    final resolver = widget.tradeIdResolver ?? _defaultTradeIdResolver;
    String? tradeId;
    try {
      tradeId = await resolver(_matchId);
    } catch (_) {
      tradeId = null;
    }
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!(tradeId);
    } else {
      Navigator.of(
        context,
      ).pushReplacementNamed(kQRConfirmedRoute, arguments: tradeId);
    }
  }

  // ── Pulse management ──────────────────────────────────────────────────────

  void _managePulse(bool isDanger) {
    if (isDanger && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isDanger && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _matchSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Pulse for the bottom half of the refresh cycle as a "rotating soon" cue
    // (mirrors the prototype, which pulses the bottom half of its loop).
    final isDanger = _seconds < _refreshSeconds ~/ 2;
    _managePulse(isDanger);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text(
          'Confirm exchange',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: _kSurface,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // No cog, no info icon — hierarchical top bar only.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Trade summary strip ────────────────────────────────────────
            if (widget.partnerName != null)
              _TradeSummaryStrip(
                partnerName: widget.partnerName!,
                partnerPhotoUrl: widget.partnerPhotoUrl,
                myItemName: widget.myItemName,
                theirItemName: widget.theirItemName,
              ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Instruction copy — partner name in bold when available.
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Show this to '),
                          TextSpan(
                            text: widget.partnerName ?? 'your swap partner',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary,
                            ),
                          ),
                          const TextSpan(text: ' to confirm the swap.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _kTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── QR Code ──────────────────────────────────────────
                    _QrCard(token: _token, hasError: _tokenError),
                    const SizedBox(height: 16),

                    // ── Countdown ────────────────────────────────────────
                    _Countdown(
                      seconds: _seconds,
                      isDanger: isDanger,
                      pulseAnimation: _pulseAnimation,
                    ),
                    const SizedBox(height: 16),

                    // ── Fraud explainer ──────────────────────────────────
                    const _FraudExplainer(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Cancel ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
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
// _QrCard — QR code container with corner markers
// ---------------------------------------------------------------------------

class _QrCard extends StatelessWidget {
  final String? token;
  final bool hasError;

  const _QrCard({required this.token, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // QR or placeholder
          SizedBox(width: 220, height: 220, child: _buildQrContent()),
          // Corner markers (green L-brackets at each corner)
          const Positioned(
            top: 0,
            left: 0,
            child: _CornerMarker(corner: _Corner.topLeft),
          ),
          const Positioned(
            top: 0,
            right: 0,
            child: _CornerMarker(corner: _Corner.topRight),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            child: _CornerMarker(corner: _Corner.bottomLeft),
          ),
          const Positioned(
            bottom: 0,
            right: 0,
            child: _CornerMarker(corner: _Corner.bottomRight),
          ),
        ],
      ),
    );
  }

  Widget _buildQrContent() {
    if (hasError) {
      return const _QrError();
    }
    if (token == null || token!.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _kGreenPrimary),
      );
    }
    return QrImageView(
      data: token!,
      version: QrVersions.auto,
      size: 220,
      backgroundColor: _kSurface,
      // Error correction level H for robustness when partially obscured.
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
  }
}

class _QrError extends StatelessWidget {
  const _QrError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, size: 32, color: _kTextSecondary),
            SizedBox(height: 8),
            Text(
              "Couldn't load QR code. Check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CornerMarker — green L-bracket corner decoration
// ---------------------------------------------------------------------------

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMarker extends StatelessWidget {
  final _Corner corner;

  const _CornerMarker({required this.corner});

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    const thickness = 3.0;
    const color = _kGreenPrimary;

    final isTop = corner == _Corner.topLeft || corner == _Corner.topRight;
    final isLeft = corner == _Corner.topLeft || corner == _Corner.bottomLeft;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Horizontal bar
          Positioned(
            top: isTop ? 0 : null,
            bottom: isTop ? null : 0,
            left: 0,
            right: 0,
            child: Container(height: thickness, color: color),
          ),
          // Vertical bar
          Positioned(
            left: isLeft ? 0 : null,
            right: isLeft ? null : 0,
            top: 0,
            bottom: 0,
            child: Container(width: thickness, color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Countdown — pill showing seconds remaining with danger state
// ---------------------------------------------------------------------------

class _Countdown extends StatelessWidget {
  final int seconds;
  final bool isDanger;
  final Animation<double> pulseAnimation;

  const _Countdown({
    required this.seconds,
    required this.isDanger,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDanger ? _kWarningBg : _kSurfaceAlt;
    final textColor = isDanger ? _kWarning : _kTextSecondary;
    final valueColor = isDanger ? _kWarning : _kTextPrimary;

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.autorenew, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            'New code in ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          Text(
            '${seconds}s',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (isDanger) {
      pill = AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) =>
            Transform.scale(scale: pulseAnimation.value, child: child),
        child: pill,
      );
    }

    return pill;
  }
}

// ---------------------------------------------------------------------------
// _FraudExplainer — informational strip below the QR
// ---------------------------------------------------------------------------

class _FraudExplainer extends StatelessWidget {
  const _FraudExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, size: 16, color: _kGreenPrimary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Each QR is signed server-side and expires in 60s. '
              "Both sides must scan to count toward your impact — solo scans don't.",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TradeSummaryStrip — partner avatar + item names below the top bar
// ---------------------------------------------------------------------------

class _TradeSummaryStrip extends StatelessWidget {
  final String partnerName;
  final String? partnerPhotoUrl;
  final String? myItemName;
  final String? theirItemName;

  const _TradeSummaryStrip({
    required this.partnerName,
    this.partnerPhotoUrl,
    this.myItemName,
    this.theirItemName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _PartnerAvatar(name: partnerName, photoUrl: partnerPhotoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Swap with ${partnerName.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (myItemName != null || theirItemName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (myItemName != null)
                          Flexible(
                            child: Text(
                              myItemName!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _kTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (myItemName != null && theirItemName != null)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.swap_horiz,
                              size: 12,
                              color: _kGreenPrimary,
                            ),
                          ),
                        if (theirItemName != null)
                          Flexible(
                            child: Text(
                              theirItemName!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _kTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
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
// _PartnerAvatar — 32px circular avatar with initial fallback
// ---------------------------------------------------------------------------

class _PartnerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _PartnerAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, st) => _buildInitial(initial),
        ),
      );
    }
    return _buildInitial(initial);
  }

  Widget _buildInitial(String initial) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFE1F5EE),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F6E56),
        ),
      ),
    );
  }
}
