import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../models/user.dart' as app_user;
import '../../services/district_service.dart';
import '../../services/photo_service.dart';
import '../../widgets/district_picker.dart';

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

const int _kBioMax = 140; // matches WBS 3.6 schema: bio max 140 chars

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Merges fields into `/users/{uid}` in Firestore.
typedef UserDocUpdater =
    Future<void> Function(String uid, Map<String, dynamic> data);

/// Returns the current Firebase Auth user's UID, or null when not signed in.
typedef CurrentUidGetter = String? Function();

UserDocUpdater _defaultUserDocUpdater() {
  return (String uid, Map<String, dynamic> data) =>
      FirebaseFirestore.instance.collection('users').doc(uid).update(data);
}

String? _defaultCurrentUidGetter() =>
    firebase_auth.FirebaseAuth.instance.currentUser?.uid;

// ---------------------------------------------------------------------------
// EditProfileScreen
// ---------------------------------------------------------------------------

/// Edit Profile screen — pre-filled form that writes changes back to Firestore
/// and pops back to the Profile view on save.
///
/// Corresponds to `EditProfileScreen` in `prototype/src/screens/editprofile.jsx`.
///
/// Fields:
///   1. Photo — tappable avatar with camera badge (optional)
///   2. Display name — required, same validation as Step 1
///   3. Home district — DistrictRow opens the district picker sheet
///   4. Bio — optional, max 140 chars, with char counter
///
/// Top bar: hierarchical (back arrow + "Edit profile" title) — no cog or info.
///
/// [initialUser], [updateUserDoc], [getCurrentUid], [photoService], and
/// [districtService] are injectable for tests.
class EditProfileScreen extends StatefulWidget {
  /// Pre-fill values from the current user document. May be null when first
  /// loading before the Firestore snapshot arrives (rare, handled gracefully).
  final app_user.User? initialUser;

  /// Injectable Firestore updater — defaults to real Firestore.
  final UserDocUpdater? updateUserDoc;

  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final String? Function()? getCurrentUid;

  /// Injectable [PhotoService] — defaults to production instance.
  final PhotoService? photoService;

  /// Injectable [DistrictService] — defaults to production instance.
  final DistrictService? districtService;

  /// Called after a successful save instead of [Navigator.pop] when provided.
  /// Primarily used in tests to verify the save callback fires.
  final VoidCallback? onSaved;

  const EditProfileScreen({
    super.key,
    this.initialUser,
    this.updateUserDoc,
    this.getCurrentUid,
    this.photoService,
    this.districtService,
    this.onSaved,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _bioController = TextEditingController();

  /// Currently selected district (from DistrictRow / picker).
  DistrictEntry? _district;

  /// Photo URL — updated when user picks a new photo.
  String _photoUrl = '';

  /// Upload progress in [0, 1], or null when idle.
  double? _uploadProgress;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  /// Validation error for the display name field.
  String? _nameError;

  // ── Injected dependencies ────────────────────────────────────────────────

  UserDocUpdater get _updateUserDoc =>
      widget.updateUserDoc ?? _defaultUserDocUpdater();

  String? Function() get _getCurrentUid =>
      widget.getCurrentUid ?? _defaultCurrentUidGetter;

  PhotoService get _photoService => widget.photoService ?? PhotoService();

  DistrictService get _districtService =>
      widget.districtService ?? DistrictService();

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _prefillFromUser(widget.initialUser);
  }

  void _prefillFromUser(app_user.User? user) {
    if (user == null) return;
    _nameController.text = user.displayName;
    _bioController.text = user.bio;
    _photoUrl = user.photoUrl;

    // Convert HomeDistrict → DistrictEntry only when the district has data.
    final hd = user.homeDistrict;
    if (hd.districtId.isNotEmpty) {
      _district = DistrictEntry(
        provinceId: hd.provinceId,
        provinceNameTh: hd.provinceNameTh,
        provinceNameEn: hd.provinceNameEn,
        districtId: hd.districtId,
        districtNameTh: hd.districtNameTh,
        districtNameEn: hd.districtNameEn,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────

  String? _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Display name is required.';
    if (trimmed.length > 40)
      return 'Display name must be 40 characters or fewer.';
    return null;
  }

  bool get _canSave {
    return _validateName(_nameController.text) == null &&
        _bioController.text.length <= _kBioMax &&
        !_isSaving &&
        _uploadProgress == null;
  }

  // ── Actions ──────────────────────────────────────────────────────────────

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
          _uploadProgress = null;
        });
      } else {
        setState(() => _uploadProgress = null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadProgress = null);
    }
  }

  Future<void> _handleSave() async {
    final nameError = _validateName(_nameController.text);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() {
      _isSaving = true;
      _nameError = null;
    });

    try {
      final data = <String, dynamic>{
        'displayName': _nameController.text.trim(),
        'bio': _bioController.text,
        'photoUrl': _photoUrl,
      };

      if (_district != null) {
        data['homeDistrict'] = _district!.toJson();
      }

      await _updateUserDoc(uid, data);

      if (!mounted) return;

      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: const BackButton(color: _kTextPrimary),
        title: const Text(
          'Edit profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _kBorder),
        ),
      ),
      body: Column(
        children: [
          // Scrollable form area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1 — Photo
                  _FieldSection(
                    label: 'Photo',
                    child: Center(
                      child: Column(
                        children: [
                          _EditableAvatar(
                            key: const Key('editableAvatar'),
                            photoUrl: _photoUrl,
                            initial: _nameController.text.isNotEmpty
                                ? _nameController.text[0].toUpperCase()
                                : '?',
                            uploadProgress: _uploadProgress,
                            onTap: _handlePickPhoto,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            key: const Key('changePhotoButton'),
                            onPressed: _handlePickPhoto,
                            style: TextButton.styleFrom(
                              foregroundColor: _kGreenPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: const Text(
                              'Change photo',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2 — Display name
                  _FieldSection(
                    label: 'Display name',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EpTextField(
                          key: const Key('displayNameField'),
                          controller: _nameController,
                          focusNode: _nameFocus,
                          placeholder: 'Your name',
                          onChanged: (_) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            } else {
                              setState(() {});
                            }
                          },
                        ),
                        if (_nameError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _nameError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kDanger,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'This is what other swappers see.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kTextTertiary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3 — Home district
                  _FieldSection(
                    label: 'Home district',
                    child: DistrictRow(
                      key: const Key('districtRow'),
                      value: _district,
                      service: _districtService,
                      onChanged: (entry) {
                        setState(() => _district = entry);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4 — Bio
                  _FieldSection(
                    label: 'Bio (optional)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _EpTextArea(
                          key: const Key('bioField'),
                          controller: _bioController,
                          placeholder:
                              'A line or two about what you swap and why.',
                          maxLength: _kBioMax,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_bioController.text.length}/$_kBioMax',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Sticky bottom save button
          Container(
            decoration: const BoxDecoration(
              color: _kSurface,
              border: Border(top: BorderSide(color: _kBorder, width: 1)),
            ),
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('saveButton'),
                onPressed: _canSave ? _handleSave : null,
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
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FieldSection — label + child atom
// ---------------------------------------------------------------------------

class _FieldSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _kTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _EpTextField — text input matching editprofile.jsx EpTextField
// ---------------------------------------------------------------------------

class _EpTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  const _EpTextField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.placeholder,
    this.onChanged,
  });

  @override
  State<_EpTextField> createState() => _EpTextFieldState();
}

class _EpTextFieldState extends State<_EpTextField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode?.hasFocus ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: const TextStyle(fontSize: 15, color: _kTextPrimary),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: const TextStyle(fontSize: 15, color: _kTextTertiary),
        filled: true,
        fillColor: _kSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        constraints: const BoxConstraints(minHeight: 48),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _focused ? _kGreenPrimary : _kBorder,
            width: _focused ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGreenPrimary, width: 1.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EpTextArea — textarea matching editprofile.jsx EpTextArea
// ---------------------------------------------------------------------------

class _EpTextArea extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  const _EpTextArea({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.maxLength,
    this.onChanged,
  });

  @override
  State<_EpTextArea> createState() => _EpTextAreaState();
}

class _EpTextAreaState extends State<_EpTextArea> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      maxLines: 4,
      maxLength: widget.maxLength,
      style: const TextStyle(fontSize: 15, height: 1.45, color: _kTextPrimary),
      onChanged: (v) {
        widget.onChanged?.call(v);
      },
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: const TextStyle(fontSize: 15, color: _kTextTertiary),
        filled: true,
        fillColor: _kSurfaceAlt,
        counterText: '', // hide built-in counter (we render our own)
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: _focused ? _kGreenPrimary : _kBorder,
            width: _focused ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _kGreenPrimary, width: 1.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EditableAvatar — avatar with camera badge, matches EditableAvatar in JSX
// ---------------------------------------------------------------------------

class _EditableAvatar extends StatelessWidget {
  final String photoUrl;
  final String initial;
  final double? uploadProgress;
  final VoidCallback onTap;

  const _EditableAvatar({
    super.key,
    required this.photoUrl,
    required this.initial,
    required this.uploadProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: [
            // Avatar circle
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreenSoft,
              ),
              clipBehavior: Clip.antiAlias,
              child: uploadProgress != null
                  ? Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: uploadProgress,
                          color: _kGreenDark,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : photoUrl.isNotEmpty
                  ? Image.network(photoUrl, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          color: _kGreenDark,
                        ),
                      ),
                    ),
            ),

            // Camera badge — bottom right
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGreenPrimary,
                  border: Border.all(color: _kSurface, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
