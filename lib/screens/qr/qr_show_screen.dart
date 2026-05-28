/// QR Show Screen — WBS 10.3
///
/// Calls the `issueQRToken` Cloud Function on mount and silently refreshes
/// every 30 seconds. Renders the returned JWT as a QR code using `qr_flutter`.
/// Shows a 60-second countdown that resets to 60 on each refresh. Listens to
/// `/matches/{matchId}` for `status: 'completed'` and navigates to the Swap
/// Confirmed screen when it fires. Cancel returns to the previous screen (chat).
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
  /// Called when the match completes (status → 'completed').
  ///
  /// When null, navigates to '/qr/confirmed' with [matchId] as the argument.
  final VoidCallback? onComplete;

  /// Injectable Cloud Function replacement (for tests).
  final TokenFetcher? tokenFetcher;

  /// Injectable Firestore stream replacement (for tests).
  final MatchStreamFactory? matchStream;

  const QrShowScreen({
    super.key,
    this.onComplete,
    this.tokenFetcher,
    this.matchStream,
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
  int _seconds = 60; // counts from 60 down to 0 then resets
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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
        // Reset countdown to 60 on each successful refresh.
        _seconds = 60;
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
        // Token refresh will reset _seconds to 60 every 30s.
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

  void _onMatchCompleted() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(
        context,
      ).pushReplacementNamed('/qr/confirmed', arguments: _matchId);
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
    final isDanger = _seconds < 30;
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
            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Instruction copy
                    const Text(
                      'Show this to your swap partner to confirm the swap.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
          Icon(Icons.access_time, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            'Expires in ',
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
