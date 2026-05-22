import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Writes fields to `/users/{uid}` in Firestore.
typedef UserDocUpdater =
    Future<void> Function(String uid, Map<String, dynamic> data);

UserDocUpdater _defaultUserDocUpdater() {
  return (String uid, Map<String, dynamic> data) =>
      FirebaseFirestore.instance.collection('users').doc(uid).update(data);
}

/// Returns the current Firebase Auth user's UID, or null when not signed in.
typedef CurrentUidGetter = String? Function();

String? _defaultCurrentUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// Step3Bio screen
// ---------------------------------------------------------------------------

/// Profile Setup step 3 — 140-character bio editor.
///
/// - Bio is optional; tapping "Start swapping" or "Skip" with an empty field
///   writes an empty string to `/users/{uid}.bio`.
/// - Hard cap at 140 chars is enforced by [LengthLimitingTextInputFormatter].
/// - Live character counter shows "X / 140" and updates on every keystroke.
/// - On completion, writes `bio` to `/users/{uid}` then invokes [onDone].
///
/// [updateUserDoc] and [getCurrentUid] are injectable for tests.
class Step3Bio extends StatefulWidget {
  /// Called when the user taps "Start swapping" or "Skip" and data has been
  /// persisted.
  final VoidCallback? onDone;

  /// Called when the user taps the back arrow.
  final VoidCallback? onBack;

  /// Injectable Firestore writer — defaults to real Firestore.
  final UserDocUpdater? updateUserDoc;

  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  const Step3Bio({
    super.key,
    this.onDone,
    this.onBack,
    this.updateUserDoc,
    this.getCurrentUid,
  });

  @override
  State<Step3Bio> createState() => _Step3BioState();
}

class _Step3BioState extends State<Step3Bio> {
  final _bioController = TextEditingController();
  final _bioFocus = FocusNode();

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  @override
  void dispose() {
    _bioController.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  UserDocUpdater get _updateUserDoc =>
      widget.updateUserDoc ?? _defaultUserDocUpdater();
  CurrentUidGetter get _getCurrentUid =>
      widget.getCurrentUid ?? _defaultCurrentUidGetter;

  String get _bio => _bioController.text;
  int get _charCount => _bio.length;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleDone() async {
    if (_isSaving) return;
    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await _updateUserDoc(uid, {'bio': _bio});
      if (mounted) widget.onDone?.call();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: _kTextPrimary),
                onPressed: widget.onBack,
              )
            : const BackButton(color: _kTextPrimary),
        // Skip link on the right — bio is optional
        actions: [
          TextButton(
            key: const Key('skipButton'),
            onPressed: _isSaving ? null : _handleDone,
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 14,
                color: _kTextSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Tell people about yourself',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle
                  const Text(
                    'One short line is enough.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bio field label
                  const Text(
                    'Short bio',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Bio textarea
                  TextField(
                    key: const Key('bioField'),
                    controller: _bioController,
                    focusNode: _bioFocus,
                    maxLines: 4,
                    minLines: 4,
                    // Hard cap at 140 chars — enforced client-side
                    inputFormatters: [LengthLimitingTextInputFormatter(140)],
                    decoration: InputDecoration(
                      hintText: 'A line or two about what you swap and why.',
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        color: _kTextTertiary,
                      ),
                      filled: true,
                      fillColor: _kSurfaceAlt,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: _kGreenPrimary,
                          width: 2,
                        ),
                      ),
                      // Suppress the default counter — we render our own below
                      counterText: '',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: _kTextPrimary,
                      height: 1.45,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Live character counter "X / 140"
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      key: const Key('charCounter'),
                      '$_charCount / 140',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom CTA — "Start swapping"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('startSwappingButton'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreenPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kGreenPrimary.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onPressed: _isSaving ? null : _handleDone,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Start swapping'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
