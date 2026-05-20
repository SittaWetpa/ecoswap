import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/photo_service.dart';

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
const _kDanger = Color(0xFFC44545);

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Writes fields to `/users/{uid}` in Firestore.
typedef UserDocUpdater = Future<void> Function(
    String uid, Map<String, dynamic> data);

UserDocUpdater _defaultUserDocUpdater() {
  return (String uid, Map<String, dynamic> data) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(data);
}

/// Returns the current Firebase Auth user's UID, or null when not signed in.
typedef CurrentUidGetter = String? Function();

String? _defaultCurrentUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// PhotoUpload widget  (matches prototype PhotoUpload component)
// ---------------------------------------------------------------------------

/// Avatar circle with camera-badge overlay.
///
/// Shows an initial letter when no photo has been picked, or a confirmation
/// label when [hasPhoto] is true.  Tapping anywhere on the circle triggers
/// [onTap].
class PhotoUpload extends StatelessWidget {
  /// First letter of the display name — shown when no photo is set.
  final String initial;

  /// Whether a photo has been picked (switches the inner label).
  final bool hasPhoto;

  /// Called when the user taps the avatar circle or the camera badge.
  final VoidCallback onTap;

  /// Upload progress in [0, 1], or null when no upload is in progress.
  final double? uploadProgress;

  const PhotoUpload({
    super.key,
    required this.initial,
    required this.hasPhoto,
    required this.onTap,
    this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              children: [
                // Avatar circle
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasPhoto ? const Color(0xFFB8D4C0) : _kGreenSoft,
                  ),
                  child: Center(
                    child: uploadProgress != null
                        ? SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              value: uploadProgress,
                              color: _kGreenDark,
                              strokeWidth: 3,
                            ),
                          )
                        : hasPhoto
                            ? Text(
                                'your photo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: _kGreenDark.withValues(alpha: 0.7),
                                  height: 1.3,
                                ),
                              )
                            : Text(
                                initial.isEmpty ? 'N' : initial,
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w600,
                                  color: _kGreenDark,
                                ),
                              ),
                  ),
                ),
                // Camera badge — bottom-right corner
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kGreenPrimary,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: _kSurface, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          hasPhoto ? 'Tap to change' : 'Tap to add a photo',
          style: const TextStyle(
            fontSize: 13,
            color: _kTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step1NamePhoto screen
// ---------------------------------------------------------------------------

/// Profile Setup step 1 — display name and optional profile photo.
///
/// - Display name is required (1–40 chars). Validated client-side before
///   enabling the Next button and before writing to Firestore.
/// - Photo is optional; skipping leaves `photoUrl` as empty string in
///   `/users/{uid}`.
/// - On "Next" the screen writes `displayName` (and `photoUrl` if a photo
///   was uploaded) to `/users/{uid}` then invokes [onNext].
///
/// [photoService], [updateUserDoc], and [getCurrentUid] are injectable for
/// tests.
class Step1NamePhoto extends StatefulWidget {
  /// Called when the user taps "Next" and all data has been persisted.
  final VoidCallback? onNext;

  /// Called when the user taps the back arrow.
  final VoidCallback? onBack;

  /// Injectable [PhotoService] — defaults to production instance.
  final PhotoService? photoService;

  /// Injectable Firestore writer — defaults to real Firestore.
  final UserDocUpdater? updateUserDoc;

  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  const Step1NamePhoto({
    super.key,
    this.onNext,
    this.onBack,
    this.photoService,
    this.updateUserDoc,
    this.getCurrentUid,
  });

  @override
  State<Step1NamePhoto> createState() => _Step1NamePhotoState();
}

class _Step1NamePhotoState extends State<Step1NamePhoto> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  /// Whether a photo has been successfully picked and uploaded.
  bool _hasPhoto = false;

  /// The uploaded photo URL, or empty string when no photo was picked.
  String _photoUrl = '';

  /// Upload progress in [0, 1], or null when idle.
  double? _uploadProgress;

  /// Whether a save operation (upload + Firestore write) is in progress.
  bool _isSaving = false;

  /// Validation error for the display name field.
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  PhotoService get _photoService => widget.photoService ?? PhotoService();
  UserDocUpdater get _updateUserDoc =>
      widget.updateUserDoc ?? _defaultUserDocUpdater();
  CurrentUidGetter get _getCurrentUid =>
      widget.getCurrentUid ?? _defaultCurrentUidGetter;

  String get _name => _nameController.text;
  String get _initial => _name.isEmpty ? 'N' : _name[0].toUpperCase();

  /// Returns a validation message for [name], or null when valid.
  String? _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Display name is required.';
    if (trimmed.length > 40) return 'Display name must be 40 characters or fewer.';
    return null;
  }

  bool get _canProceed =>
      _validateName(_name) == null && !_isSaving && _uploadProgress == null;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handlePickPhoto() async {
    if (_isSaving) return;
    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() => _uploadProgress = 0);

    try {
      final url = await _photoService.pickAndUpload(
        storagePath: 'user_photos/$uid.jpg',
      );

      if (!mounted) return;

      if (url != null) {
        setState(() {
          _photoUrl = url;
          _hasPhoto = true;
          _uploadProgress = null;
        });
      } else {
        // User cancelled — reset progress without changing photo state.
        setState(() => _uploadProgress = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadProgress = null);
    }
  }

  Future<void> _handleNext() async {
    // Validate first
    final error = _validateName(_name);
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }

    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() {
      _isSaving = true;
      _nameError = null;
    });

    try {
      await _updateUserDoc(uid, {
        'displayName': _name.trim(),
        'photoUrl': _photoUrl,
      });
      if (mounted) widget.onNext?.call();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  InputDecoration _nameFieldDecoration() {
    return InputDecoration(
      labelText: 'Display name',
      labelStyle: const TextStyle(fontSize: 13, color: _kTextSecondary),
      hintText: 'Your name',
      hintStyle: const TextStyle(fontSize: 15, color: _kTextTertiary),
      filled: true,
      fillColor: _kSurfaceAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: _kGreenPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kDanger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kDanger, width: 2),
      ),
      errorText: _nameError,
      errorStyle: const TextStyle(color: _kDanger, fontSize: 12),
      constraints: const BoxConstraints(minHeight: 48),
    );
  }

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
                    'What should we call you?',
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
                    'Add a photo and a name so other swappers recognise you.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Photo upload affordance — centered
                  Center(
                    child: PhotoUpload(
                      initial: _initial,
                      hasPhoto: _hasPhoto,
                      onTap: _handlePickPhoto,
                      uploadProgress: _uploadProgress,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Display name field
                  TextField(
                    key: const Key('displayNameField'),
                    controller: _nameController,
                    focusNode: _nameFocus,
                    maxLength: 40,
                    // Hard-cap at 40 chars via formatter
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(40),
                    ],
                    textCapitalization: TextCapitalization.words,
                    decoration: _nameFieldDecoration().copyWith(
                      counterText: '',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: _kTextPrimary,
                    ),
                    onChanged: (_) {
                      // Clear error as user types
                      if (_nameError != null) {
                        setState(() => _nameError = null);
                      } else {
                        setState(() {}); // rebuild for button state
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom CTA — "Next"
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('nextButton'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreenPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _kGreenPrimary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
                onPressed: _canProceed ? _handleNext : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Next'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
