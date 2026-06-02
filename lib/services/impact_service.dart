import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Immutable result of [ImpactService.getCurrentUserImpact].
///
/// Per WBS 11.2 the return shape is intentionally tiny — just the three
/// denormalized counters off `/users/{uid}`. No trend/comparison/monthly
/// fields and no surface for trust score or activity status (locked
/// out-of-scope decisions, see CLAUDE.md).
class UserImpact {
  /// Number of completed trades for this user (`tradesCount`).
  final int trades;

  /// Total CO₂ saved in kilograms (`totalCo2Saved`).
  final double co2Kg;

  /// Total waste diverted in kilograms (`totalWasteDiverted`).
  final double wasteKg;

  const UserImpact({
    required this.trades,
    required this.co2Kg,
    required this.wasteKg,
  });

  /// Zero impact — used as the cold-start default for new users whose
  /// `/users/{uid}` document is missing the counter fields (or missing
  /// entirely).
  static const UserImpact zero = UserImpact(trades: 0, co2Kg: 0, wasteKg: 0);

  // ---------------------------------------------------------------------------
  // Shared formatting — used by both the Impact Dashboard (WBS 11.3) and the
  // Profile Impact Stat Strip (WBS 11.4). Keeping the rules in one place is
  // what guarantees the WBS 11.4 acceptance criterion "Values match what's
  // shown on the dashboard".
  //
  //   - Swaps (trades count) → integer with no decimals.
  //   - CO₂ saved (kg)       → one decimal place.
  //   - Waste diverted (kg)  → one decimal place.
  // ---------------------------------------------------------------------------

  /// Integer-formatted trades count (e.g. `7`).
  String get formattedTrades => '$trades';

  /// CO₂ saved in kg, formatted to one decimal place (e.g. `47.5`).
  String get formattedCo2Kg => co2Kg.toStringAsFixed(1);

  /// Waste diverted in kg, formatted to one decimal place (e.g. `12.3`).
  String get formattedWasteKg => wasteKg.toStringAsFixed(1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserImpact &&
          trades == other.trades &&
          co2Kg == other.co2Kg &&
          wasteKg == other.wasteKg;

  @override
  int get hashCode => Object.hash(trades, co2Kg, wasteKg);

  @override
  String toString() =>
      'UserImpact(trades: $trades, co2Kg: $co2Kg, wasteKg: $wasteKg)';
}

/// Thrown by [ImpactService.getCurrentUserImpact] when no user is currently
/// signed in. Callers (Impact Dashboard 11.3, Profile strip 11.4) should
/// only invoke the service from authenticated screens — this exception
/// guards against being wired into a public route by mistake.
class NotSignedInException implements Exception {
  final String message;
  const NotSignedInException(this.message);

  @override
  String toString() => 'NotSignedInException: $message';
}

/// Typedef for a function that fetches a single user document by UID.
///
/// Returns the document data map, or `null` if the document does not exist.
/// Tests inject a fake closure so they can run without a real Firestore
/// instance — same pattern used by [AuthService] and [ItemService].
typedef UserDocReader = Future<Map<String, dynamic>?> Function(String uid);

/// Typedef for a function that returns a *live stream* of a single user
/// document by UID.
///
/// Emits the document data map on every change, or `null` if the document
/// does not exist. The default implementation listens to Firestore
/// `snapshots()`; tests inject a fake stream so they can run without a real
/// Firestore instance.
typedef UserDocStreamReader =
    Stream<Map<String, dynamic>?> Function(String uid);

/// Typedef for resolving the currently signed-in user's UID.
///
/// Returns `null` if no user is signed in. The default implementation reads
/// from [FirebaseAuth.instance.currentUser]; tests inject a fixed value.
typedef CurrentUidProvider = String? Function();

UserDocReader _defaultUserDocReader() {
  return (String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    return snap.data();
  };
}

UserDocStreamReader _defaultUserDocStreamReader() {
  return (String uid) => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? snap.data() : null);
}

CurrentUidProvider _defaultCurrentUidProvider() {
  return () => firebase_auth.FirebaseAuth.instance.currentUser?.uid;
}

/// Service for reading the per-user impact counters denormalized onto
/// `/users/{uid}` (WBS 11.2).
///
/// The dashboard (11.3) and profile strip (11.4) both call
/// [getCurrentUserImpact]. The implementation is **one document read** —
/// no aggregation query, no client-side sum over `/trades/`. This is a
/// locked decision: the writer (10.6's transaction) keeps the counters
/// in sync atomically with the trade doc, so the read side just trusts
/// them.
///
/// All Firestore and Auth interactions are injectable via constructor
/// parameters so tests can run without a real Firebase project.
class ImpactService {
  final UserDocReader _readUserDoc;
  final UserDocStreamReader _watchUserDoc;
  final CurrentUidProvider _currentUid;

  ImpactService({
    UserDocReader? userDocReader,
    UserDocStreamReader? userDocStreamReader,
    CurrentUidProvider? currentUidProvider,
  }) : _readUserDoc = userDocReader ?? _defaultUserDocReader(),
       _watchUserDoc = userDocStreamReader ?? _defaultUserDocStreamReader(),
       _currentUid = currentUidProvider ?? _defaultCurrentUidProvider();

  /// Returns the current user's impact totals as a single
  /// document-read result.
  ///
  /// Per WBS 11.2:
  ///   - Reads exactly one document: `/users/{currentUid}`
  ///   - Returns `{ trades, co2Kg, wasteKg }` mapped from the
  ///     denormalized counters `tradesCount` / `totalCo2Saved` /
  ///     `totalWasteDiverted` written by the 10.6 transaction
  ///   - Cold start: if the user doc is missing the counter fields
  ///     (new account, no trades yet) or missing entirely, returns
  ///     [UserImpact.zero] instead of throwing
  ///
  /// Throws [NotSignedInException] if no user is signed in — callers
  /// must only invoke this from authenticated screens.
  Future<UserImpact> getCurrentUserImpact() async {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      throw const NotSignedInException(
        'getCurrentUserImpact requires a signed-in user.',
      );
    }

    final data = await _readUserDoc(uid);
    return _impactFromDoc(data);
  }

  /// Live-updating variant of [getCurrentUserImpact].
  ///
  /// Returns a stream that emits a fresh [UserImpact] every time the
  /// `/users/{currentUid}` document changes — so the Impact Dashboard's hero
  /// number and metric cards reflect a freshly-completed trade *without* an
  /// app refresh. The 10.6 transaction is still the only writer of the
  /// counters; this just observes them live instead of reading once. CO₂ is
  /// never recomputed client-side (locked decision, CLAUDE.md).
  ///
  /// Emits a [NotSignedInException] as a stream error if no user is signed in.
  /// Cold-start (missing doc or counter fields) maps to [UserImpact.zero],
  /// matching [getCurrentUserImpact].
  Stream<UserImpact> watchCurrentUserImpact() {
    final uid = _currentUid();
    if (uid == null || uid.isEmpty) {
      return Stream<UserImpact>.error(
        const NotSignedInException(
          'watchCurrentUserImpact requires a signed-in user.',
        ),
      );
    }
    return _watchUserDoc(uid).map(_impactFromDoc);
  }

  /// Maps a raw `/users/{uid}` document map to a [UserImpact].
  ///
  /// A `null` map (document missing, e.g. a brand-new user or an emulator
  /// race) becomes [UserImpact.zero] rather than throwing — both the
  /// one-shot read and the live stream should render gracefully for a user
  /// with no trades yet.
  static UserImpact _impactFromDoc(Map<String, dynamic>? data) {
    if (data == null) return UserImpact.zero;
    return UserImpact(
      trades: (data['tradesCount'] as num?)?.toInt() ?? 0,
      co2Kg: (data['totalCo2Saved'] as num?)?.toDouble() ?? 0,
      wasteKg: (data['totalWasteDiverted'] as num?)?.toDouble() ?? 0,
    );
  }
}
