import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';

import '../../services/district_service.dart';
import '../../widgets/district_picker.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);

// ---------------------------------------------------------------------------
// Typedefs — injectable for tests
// ---------------------------------------------------------------------------

/// Writes fields to `/users/{uid}` in Firestore.
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
// Step2District screen
// ---------------------------------------------------------------------------

/// Profile Setup step 2 — home district selection.
///
/// - Uses [DistrictAreaField] for searching/selecting state.
/// - On "Next" the screen writes `homeDistrict` (all six fields from
///   [DistrictEntry.toJson]) to `/users/{uid}` then invokes [onNext].
/// - The "Next" button is disabled until a district is selected.
///
/// [districtService], [updateUserDoc], and [getCurrentUid] are injectable for
/// tests.
class Step2District extends StatefulWidget {
  /// Called when the user taps "Next" and the district has been persisted.
  final VoidCallback? onNext;

  /// Called when the user taps the back arrow.
  final VoidCallback? onBack;

  /// Injectable [DistrictService] — defaults to production instance.
  final DistrictService? districtService;

  /// Injectable Firestore writer — defaults to real Firestore.
  final UserDocUpdater? updateUserDoc;

  /// Injectable UID getter — defaults to [FirebaseAuth.instance.currentUser?.uid].
  final CurrentUidGetter? getCurrentUid;

  const Step2District({
    super.key,
    this.onNext,
    this.onBack,
    this.districtService,
    this.updateUserDoc,
    this.getCurrentUid,
  });

  @override
  State<Step2District> createState() => _Step2DistrictState();
}

class _Step2DistrictState extends State<Step2District> {
  DistrictEntry? _selected;
  bool _isSaving = false;

  DistrictService get _service => widget.districtService ?? DistrictService();
  UserDocUpdater get _updateUserDoc =>
      widget.updateUserDoc ?? _defaultUserDocUpdater();
  CurrentUidGetter get _getCurrentUid =>
      widget.getCurrentUid ?? _defaultCurrentUidGetter;

  bool get _canProceed => _selected != null && !_isSaving;

  Future<void> _handleNext() async {
    if (!_canProceed) return;
    final uid = _getCurrentUid();
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      await _updateUserDoc(uid, {'homeDistrict': _selected!.toJson()});
      if (mounted) widget.onNext?.call();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kTextPrimary),
          onPressed: widget.onBack,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where are you based?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'We only show your district to others, never your exact location.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your area',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DistrictAreaField(
                    key: const Key('districtAreaField'),
                    value: _selected,
                    service: _service,
                    onChanged: (entry) => setState(() => _selected = entry),
                  ),
                ],
              ),
            ),
          ),
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
