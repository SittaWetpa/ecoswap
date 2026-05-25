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
  static const UserImpact zero = UserImpact(
    trades: 0,
    co2Kg: 0,
    wasteKg: 0,
  );

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

/// Typedef for resolving the currently signed-in user's UID.
///
/// Returns `null` if no user is signed in. The default implementation reads
/// from [FirebaseAuth.instance.currentUser]; tests inject a fixed value.
typedef CurrentUidProvider = String? Function();

UserDocReader _defaultUserDocReader() {
  return (String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  };
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
  final CurrentUidProvider _currentUid;

  ImpactService({
    UserDocReader? userDocReader,
    CurrentUidProvider? currentUidProvider,
  })  : _readUserDoc = userDocReader ?? _defaultUserDocReader(),
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
    if (data == null) {
      // Document doesn't exist (e.g., emulator race, manual deletion). Treat
      // as cold-start zeros rather than throwing — the dashboard and profile
      // strip should render gracefully for a brand-new user.
      return UserImpact.zero;
    }

    return UserImpact(
      trades: (data['tradesCount'] as num?)?.toInt() ?? 0,
      co2Kg: (data['totalCo2Saved'] as num?)?.toDouble() ?? 0,
      wasteKg: (data['totalWasteDiverted'] as num?)?.toDouble() ?? 0,
    );
  }
}
