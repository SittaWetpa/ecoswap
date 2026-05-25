/// Swipe Write Service — WBS 8.1
///
/// Writes a document to `/swipes/{swipeId}` every time the user swipes on a
/// candidate card.  The swipe document is the input to the mutual-match
/// detection Cloud Function (WBS 8.3).
///
/// Design decisions (per WBS 8.1 and 3.6):
/// - [direction] is either `'left'` or `'right'`.
/// - Left-swipes store [desiredItemId] as the empty string `''` (not null),
///   per the locked decision that Firestore requires non-null and queries are
///   more consistent without nulls.
/// - Right-swipes REQUIRE a non-empty [desiredItemId]; an [ArgumentError] is
///   thrown client-side if it is empty.
/// - Each call uses `CollectionReference.add()` which always generates a new
///   unique document ID, so rapid successive swipes can never collide.
///
/// All Firestore I/O is injectable via [swipeDocAdder] so unit tests can run
/// without a real Firebase project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// ---------------------------------------------------------------------------
// Injectable typedef
// ---------------------------------------------------------------------------

/// Adds one swipe document to Firestore and returns the generated document ID.
///
/// In production this calls [CollectionReference.add]; in tests it is replaced
/// with a fake that captures calls without touching Firebase.
typedef SwipeDocAdder = Future<String> Function(Map<String, dynamic> data);

/// Returns the default [SwipeDocAdder] that writes to the real Firestore
/// `swipes` collection.
SwipeDocAdder _defaultAdder() {
  return (Map<String, dynamic> data) async {
    final ref = await FirebaseFirestore.instance.collection('swipes').add(data);
    return ref.id;
  };
}

// ---------------------------------------------------------------------------
// SwipeService
// ---------------------------------------------------------------------------

/// Service for WBS 8.1 — Swipe Write to Firestore.
///
/// Usage (production):
/// ```dart
/// final service = SwipeService(currentUserId: FirebaseAuth.instance.currentUser!.uid);
/// await service.recordSwipe('targetUserId', 'left');
/// await service.recordSwipe('targetUserId', 'right', desiredItemId: 'itemId');
/// ```
///
/// Usage (tests — inject fakes):
/// ```dart
/// final service = SwipeService(
///   currentUserId: 'me',
///   swipeDocAdder: (data) async { captured.add(data); return 'fake-id'; },
/// );
/// ```
class SwipeService {
  final String _currentUserId;
  final SwipeDocAdder _addSwipeDoc;

  SwipeService({
    /// The authenticated user's UID.  In production, pass
    /// `FirebaseAuth.instance.currentUser!.uid`.
    required String currentUserId,

    /// Firestore add operation.  Defaults to the real Firestore collection.
    SwipeDocAdder? swipeDocAdder,
  }) : _currentUserId = currentUserId,
       _addSwipeDoc = swipeDocAdder ?? _defaultAdder();

  /// Convenience constructor that reads the current user from [FirebaseAuth].
  ///
  /// Throws [StateError] if no user is signed in.
  factory SwipeService.fromAuth({SwipeDocAdder? swipeDocAdder}) {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError(
        'SwipeService.fromAuth() called with no signed-in user.',
      );
    }
    return SwipeService(currentUserId: user.uid, swipeDocAdder: swipeDocAdder);
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Records one swipe on [targetUserId] in the direction [direction].
  ///
  /// [direction] must be `'left'` or `'right'`.
  ///
  /// For right-swipes, [desiredItemId] must be non-empty — it is the ID of
  /// the target user's item the swiper wants.  Passing an empty string (or
  /// omitting it) for a right-swipe throws [ArgumentError].
  ///
  /// For left-swipes, [desiredItemId] is always stored as `''` (empty string
  /// sentinel), regardless of the value passed in.
  ///
  /// Returns the Firestore document ID of the newly created swipe record.
  Future<String> recordSwipe(
    String targetUserId,
    String direction, {
    String desiredItemId = '',
  }) async {
    if (direction == 'right' && desiredItemId.isEmpty) {
      throw ArgumentError(
        'desiredItemId must not be empty for a right-swipe. '
        'The item picker (WBS 8.2) must supply a valid item ID before calling '
        'recordSwipe with direction: right.',
      );
    }

    // Left-swipes always store '' — normalise here so callers cannot
    // accidentally store a stale item ID on a left-swipe.
    final storedItemId = direction == 'right' ? desiredItemId : '';

    final data = <String, dynamic>{
      'swiperId': _currentUserId,
      'targetUserId': targetUserId,
      'direction': direction,
      'desiredItemId': storedItemId,
      'createdAt': FieldValue.serverTimestamp(),
    };

    return _addSwipeDoc(data);
  }
}
