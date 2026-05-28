/// QR Scan Screen — WBS 10.4 + WBS 10.5
///
/// Displays a live camera viewfinder using [mobile_scanner]. Scans QR codes
/// continuously; when one is detected it calls the [validateQRToken] Cloud
/// Function and either navigates to Swap Confirmed or shows a toast with a
/// user-friendly message for each typed error code.
///
/// Camera permission is requested by [mobile_scanner] on first use. If denied,
/// the screen renders an explanation message with a link to app settings.
///
/// Injectable seams (for widget tests — no real camera or Firebase needed):
///   [scannerBuilder]   — replaces the live [MobileScanner] widget
///   [tokenValidator]   — replaces the [validateQRToken] callable
///   [permissionDenied] — when true, skips the camera and shows the
///                        permission-denied fallback directly (test seam only)
///   [openSettingsCallback] — replaces the platform settings opener
///
/// WBS 10.5 — DEV-MODE paste-token fallback:
///   When [kDevMode] is true (build flag `--dart-define=DEV_MODE=true`), a
///   text field and Submit button are shown below the camera viewfinder.
///   Pasting a JWT and tapping Submit calls [tokenValidator] exactly as a
///   camera scan would. This path is ABSENT in release builds (kDevMode is
///   always false when the flag is omitted or set to false).
///
/// Locked decisions:
///   - Top bar: "Confirm exchange" title, back arrow only (hierarchical).
///   - No GPS, no km, no distance, no verification badge.
///   - Vocabulary: "swap" in UI copy, never "trade".
///   - Error codes defined in WBS 10.2 are translated to friendly strings here.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ---------------------------------------------------------------------------
// Build flag — DEV-MODE paste-token fallback (WBS 10.5)
//
// Set to true at build time via: flutter run --dart-define=DEV_MODE=true
// Defaults to false — NEVER true in release builds.
// The CI build-apk job explicitly passes --dart-define=DEV_MODE=false.
// ---------------------------------------------------------------------------

/// When true, a paste-token text field appears below the camera viewfinder,
/// allowing manual JWT entry without a second physical device.
///
/// Only ever true when the app is built with `--dart-define=DEV_MODE=true`.
/// Omitting the flag or building with `--release` leaves this false.
const bool kDevMode = bool.fromEnvironment('DEV_MODE');

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);

// ---------------------------------------------------------------------------
// Error-code → user-facing message mapping (WBS 10.4 Deliverables)
// ---------------------------------------------------------------------------

/// Maps a typed error code returned by [validateQRToken] to user-facing copy.
///
/// All five codes defined in WBS 10.2 are covered. Unrecognised codes fall
/// back to a generic message.
String _toastForErrorCode(String? code) {
  switch (code) {
    case 'INVALID_SIGNATURE':
      return 'QR not recognised, try again';
    case 'EXPIRED':
      return 'QR expired, ask them to refresh';
    case 'WRONG_COUNTERPARTY':
      return "You can't scan your own QR";
    case 'ALREADY_USED':
      return 'This swap is already complete';
    case 'MATCH_INVALID':
      return 'This match is no longer active';
    default:
      return 'Something went wrong, please try again';
  }
}

// ---------------------------------------------------------------------------
// Injectable typedefs
// ---------------------------------------------------------------------------

/// Builds the scanner widget and calls [onDetect] with the raw QR string
/// whenever a code is recognised.
///
/// Production value: [_defaultScannerBuilder] which creates a [MobileScanner].
/// Test value: any widget that calls [onDetect] with a known token.
typedef ScannerBuilder =
    Widget Function(void Function(String rawValue) onDetect);

/// Calls the [validateQRToken] Cloud Function with the scanned token for the
/// given match and returns `{ 'success': true, 'tradeId': String }` on
/// success, or throws a [FirebaseFunctionsException] with a typed message.
///
/// Production value: [_defaultTokenValidator].
/// Test value: a synchronous function that returns fake data or throws.
typedef TokenValidator =
    Future<Map<String, dynamic>> Function(String matchId, String token);

// ---------------------------------------------------------------------------
// Production implementations
// ---------------------------------------------------------------------------

/// Builds the real [MobileScanner] widget wired to [onDetect].
///
/// Continuous scanning is the default — no tap needed.
Widget _defaultScannerBuilder(void Function(String rawValue) onDetect) {
  return MobileScanner(
    onDetect: (capture) {
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) {
          onDetect(raw);
          return; // pass the first valid barcode per capture
        }
      }
    },
    errorBuilder: (context, error) {
      if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
        // No openSettingsCallback injected in production — instruction text
        // is shown and the button is a no-op (user reads the copy instead).
        return const _PermissionDeniedPlaceholder();
      }
      return const _CameraErrorPlaceholder();
    },
  );
}

/// Calls the [validateQRToken] callable Cloud Function.
Future<Map<String, dynamic>> _defaultTokenValidator(
  String matchId,
  String token,
) async {
  final callable = FirebaseFunctions.instance.httpsCallable('validateQRToken');
  final result = await callable.call<Map<dynamic, dynamic>>({
    'matchId': matchId,
    'token': token,
  });
  return Map<String, dynamic>.from(result.data);
}

// ---------------------------------------------------------------------------
// QrScanScreen
// ---------------------------------------------------------------------------

/// QR Scan screen — WBS 10.4.
///
/// [matchId] is passed as a route argument:
///   `Navigator.pushNamed(context, '/qr/scan', arguments: matchId)`
///
/// In tests, inject [scannerBuilder], [tokenValidator], [permissionDenied],
/// and [onComplete] so the screen never touches Firebase or real hardware.
class QrScanScreen extends StatefulWidget {
  /// Injectable scanner widget builder (for tests).
  ///
  /// When null, uses [_defaultScannerBuilder] which creates a [MobileScanner].
  final ScannerBuilder? scannerBuilder;

  /// Injectable Cloud Function replacement (for tests).
  ///
  /// When null, calls the real `validateQRToken` Cloud Function.
  final TokenValidator? tokenValidator;

  /// When true, skips the camera view and immediately shows the
  /// permission-denied fallback. Only used in widget tests; in production the
  /// [MobileScanner.errorBuilder] handles this case.
  final bool permissionDenied;

  /// Called on a successful validate result.
  ///
  /// When null, navigates to '/qr/confirmed' with [tradeId] as the argument.
  final void Function(String tradeId)? onComplete;

  /// Swap partner's display name — shown in the instruction copy.
  final String? partnerName;

  /// Called when the user taps "Open settings" on the permission-denied screen.
  ///
  /// When null, a no-op is used in production (the instruction text is still
  /// shown). Inject in tests to assert the button is present and tappable
  /// without needing a real platform channel.
  final VoidCallback? openSettingsCallback;

  /// Test-only override for the [kDevMode] build flag.
  ///
  /// When non-null, this value takes precedence over [kDevMode], allowing
  /// widget tests to exercise both the "flag on" and "flag off" branches
  /// without recompiling with `--dart-define`. Set to `true` to show the
  /// paste field; set to `false` to assert it is absent.
  ///
  /// Never pass this in production code — use the build flag instead.
  final bool? devModeOverride;

  const QrScanScreen({
    super.key,
    this.scannerBuilder,
    this.tokenValidator,
    this.permissionDenied = false,
    this.onComplete,
    this.partnerName,
    this.openSettingsCallback,
    this.devModeOverride,
  });

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  // ── Match ID ──────────────────────────────────────────────────────────────
  late final String _matchId;
  bool _initialized = false;

  // ── Scanning state ────────────────────────────────────────────────────────

  /// Prevents multiple concurrent validate calls (the scanner fires
  /// continuously so we gate subsequent calls until the first resolves).
  bool _isValidating = false;

  // ── DEV-MODE paste-token state (WBS 10.5) ────────────────────────────────

  /// Resolves the effective DEV-MODE flag.
  ///
  /// In production [widget.devModeOverride] is always null, so [kDevMode]
  /// (the compile-time constant) is used. In widget tests [devModeOverride]
  /// is set to `true` or `false` to exercise both branches without needing a
  /// separate `--dart-define` build.
  bool get _isDevMode => widget.devModeOverride ?? kDevMode;

  /// Controller for the DEV-MODE paste-token text field.
  ///
  /// Lazily allocated only when the effective dev-mode flag is true.
  TextEditingController? _pasteController;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Allocate the paste controller only when DEV-MODE is active so no
    // resources are consumed in production builds.
    if (_isDevMode) {
      _pasteController = TextEditingController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _matchId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _pasteController?.dispose();
    super.dispose();
  }

  // ── Scan handler ──────────────────────────────────────────────────────────

  Future<void> _onScan(String rawValue) async {
    if (_isValidating) return;
    setState(() => _isValidating = true);

    final validator = widget.tokenValidator ?? _defaultTokenValidator;
    try {
      final result = await validator(_matchId, rawValue);
      if (!mounted) return;
      final tradeId = result['tradeId'] as String? ?? '';
      if (widget.onComplete != null) {
        widget.onComplete!(tradeId);
      } else {
        Navigator.of(
          context,
        ).pushReplacementNamed('/qr/confirmed', arguments: tradeId);
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = _toastForErrorCode(e.message);
      _showToast(message);
    } catch (_) {
      if (!mounted) return;
      _showToast(_toastForErrorCode(null));
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _kSurface,
          ),
        ),
        backgroundColor: _kTextPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        // Hierarchical top bar — back arrow only, no cog or info icon.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorder),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Instruction copy ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Point your camera at '),
                    TextSpan(
                      text: widget.partnerName != null
                          ? '${widget.partnerName}’s'
                          : 'your swap partner’s',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    const TextSpan(text: ' QR code.'),
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
            ),

            // ── Camera / viewfinder area ─────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildViewfinder(),
                ),
              ),
            ),

            // ── DEV-MODE paste-token fallback (WBS 10.5) ─────────────────
            //
            // Visible ONLY when the app was built with
            // --dart-define=DEV_MODE=true (or when devModeOverride: true is
            // passed in tests). Never present in release builds.
            // Matches the prototype's "Or paste code…" row below the scanner.
            if (_isDevMode)
              _DevModePasteField(
                controller: _pasteController!,
                onSubmit: _onScan,
                isValidating: _isValidating,
              ),

            // ── Loading overlay while validating ─────────────────────────
            if (_isValidating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _kGreenPrimary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 12),

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

  Widget _buildViewfinder() {
    // Permission-denied test seam: directly shows the fallback.
    if (widget.permissionDenied) {
      return _PermissionDeniedPlaceholder(
        onOpenSettings: widget.openSettingsCallback,
      );
    }

    final builder = widget.scannerBuilder ?? _defaultScannerBuilder;
    return Stack(
      children: [
        // Camera preview / injected scanner widget.
        Positioned.fill(child: builder(_onScan)),

        // Corner markers (green L-brackets from the prototype's CornerMarkers).
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

        // Animated scan line (visual-only, matches prototype animation).
        const _ScanLine(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _PermissionDeniedPlaceholder — shown when camera access is denied
// ---------------------------------------------------------------------------

class _PermissionDeniedPlaceholder extends StatelessWidget {
  /// Called when the user taps "Open settings". When null the button is
  /// present but performs no action (the instruction text guides the user).
  final VoidCallback? onOpenSettings;

  const _PermissionDeniedPlaceholder({this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurfaceAlt,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 40,
            color: _kTextSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera access needed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _kTextPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'EcoSwap needs camera access to scan QR codes. '
            'Please enable it in your device settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // "Open settings" link — tapping navigates the user to system
          // settings where they can grant camera access. The callback is
          // injectable so widget tests can verify the button is present and
          // tappable without needing a real platform channel.
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(
              foregroundColor: _kGreenPrimary,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'Open settings',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CameraErrorPlaceholder — shown on generic camera errors
// ---------------------------------------------------------------------------

class _CameraErrorPlaceholder extends StatelessWidget {
  const _CameraErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: Colors.white54),
              SizedBox(height: 12),
              Text(
                "Couldn't start the camera. Please try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CornerMarker — green L-bracket decoration (same as qr_show_screen.dart)
// ---------------------------------------------------------------------------

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMarker extends StatelessWidget {
  final _Corner corner;

  const _CornerMarker({required this.corner});

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
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
// _ScanLine — animated green horizontal bar (prototype: scanLine animation)
// ---------------------------------------------------------------------------

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // _ScanLine is placed as a direct child of a Stack in _buildViewfinder.
    // We must NOT return a Positioned here — Positioned only works when its
    // direct render-object parent is a RenderStack. Instead we fill the
    // available space with our own Stack and place the scan bar inside it
    // using Positioned, which is valid because the bar's parent Stack is
    // created right here.
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        // Animate the fractional vertical alignment from top to bottom.
        // alignmentY in [-1, 1]: -1 = top, +1 = bottom.
        // We map animation value [0, 1] → alignment [-0.8, 0.8] so the bar
        // stays inside the corner markers (16px inset on a typical 220px box).
        final alignY = -0.8 + _animation.value * 1.6;
        return Align(
          alignment: Alignment(0, alignY),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: _kGreenPrimary,
                boxShadow: [
                  BoxShadow(
                    color: _kGreenPrimary.withAlpha(102),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _DevModePasteField — DEV-MODE paste-token fallback (WBS 10.5)
//
// Rendered ONLY when kDevMode is true (--dart-define=DEV_MODE=true).
// Matches the prototype's "Or paste code…" row below ScannerViewfinder:
//   [ paste input field .................. ] [ Submit ]
//
// Tapping Submit calls [onSubmit] with the trimmed field value, which feeds
// directly into _QrScanScreenState._onScan — the same path as a camera scan.
// The injectable [onSubmit] seam means widget tests never touch Firebase.
// ---------------------------------------------------------------------------

class _DevModePasteField extends StatelessWidget {
  final TextEditingController controller;

  /// Called with the trimmed token text when the user taps Submit.
  ///
  /// Maps to [_QrScanScreenState._onScan] in production.
  final void Function(String token) onSubmit;

  /// When true the Submit button is disabled (validate already in progress).
  final bool isValidating;

  const _DevModePasteField({
    required this.controller,
    required this.onSubmit,
    required this.isValidating,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _kSurfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            // Paste input — monospace, matches prototype's JetBrains Mono style.
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: _kTextSecondary,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: 'Or paste code…',
                  hintStyle: TextStyle(fontSize: 13, color: _kTextSecondary),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                enabled: !isValidating,
                // Allow submitting via the keyboard action button.
                onSubmitted: (value) {
                  final token = value.trim();
                  if (token.isNotEmpty) onSubmit(token);
                },
              ),
            ),
            const SizedBox(width: 8),
            // Submit button — green, matches prototype's style.
            TextButton(
              onPressed: isValidating
                  ? null
                  : () {
                      final token = controller.text.trim();
                      if (token.isNotEmpty) onSubmit(token);
                    },
              style: TextButton.styleFrom(
                backgroundColor: _kGreenPrimary,
                foregroundColor: _kSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                disabledBackgroundColor: _kGreenPrimary,
                disabledForegroundColor: _kSurface,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
