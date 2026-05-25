/// Chat Service — WBS 9.5
///
/// Provides [markRead] which batch-updates the `readBy` array on message
/// documents, appending [currentUserId] to each message in [messageIds].
///
/// Design decisions:
/// - Uses `WriteBatch` + `FieldValue.arrayUnion` for idempotency: calling
///   `markRead` twice with the same IDs is a no-op at the Firestore layer.
/// - All Firestore I/O is injectable via [batchCommitter] so unit tests can
///   run without a real Firebase project (same pattern as SwipeService).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Public data class
// ---------------------------------------------------------------------------

/// Carries the parameters for a single `readBy` update within a batch.
///
/// Exposed publicly so [BatchCommitter] implementations (including test fakes)
/// can inspect the fields without dynamic casting.
class ReadUpdate {
  final String matchId;
  final String messageId;
  final String userId;

  const ReadUpdate({
    required this.matchId,
    required this.messageId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      other is ReadUpdate &&
      other.matchId == matchId &&
      other.messageId == messageId &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(matchId, messageId, userId);
}

// ---------------------------------------------------------------------------
// Injectable typedef
// ---------------------------------------------------------------------------

/// Commits a batch of readBy updates to Firestore.
///
/// Receives a list of [ReadUpdate] records (each carrying the document path
/// and the user ID to append) and executes a single [WriteBatch] commit.
///
/// In production this calls real Firestore; in tests it is replaced with a
/// fake that captures calls without touching Firebase.
typedef BatchCommitter = Future<void> Function(List<ReadUpdate> updates);

/// Returns the default [BatchCommitter] that writes to real Firestore.
BatchCommitter _defaultCommitter() {
  return (List<ReadUpdate> updates) async {
    if (updates.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final u in updates) {
      final ref = FirebaseFirestore.instance
          .collection('matches')
          .doc(u.matchId)
          .collection('messages')
          .doc(u.messageId);
      batch.update(ref, {
        'readBy': FieldValue.arrayUnion([u.userId]),
      });
    }
    await batch.commit();
  };
}

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

/// Service for WBS 9.5 — Read Receipt Logic.
///
/// Usage (production):
/// ```dart
/// final service = ChatService();
/// await service.markRead(
///   matchId: 'match123',
///   currentUserId: FirebaseAuth.instance.currentUser!.uid,
///   messageIds: ['msg1', 'msg2'],
/// );
/// ```
///
/// Usage (tests — inject fakes):
/// ```dart
/// final captured = <List<ReadUpdate>>[];
/// final service = ChatService(
///   batchCommitter: (updates) async { captured.add(updates); },
/// );
/// ```
class ChatService {
  final BatchCommitter _commit;

  ChatService({
    /// Batch commit operation.  Defaults to the real Firestore batch writer.
    BatchCommitter? batchCommitter,
  }) : _commit = batchCommitter ?? _defaultCommitter();

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Marks [messageIds] as read by [currentUserId] within [matchId].
  ///
  /// Appends [currentUserId] to each message's `readBy` array using
  /// `FieldValue.arrayUnion`, which guarantees idempotency — calling this
  /// method twice with the same arguments has the same effect as calling it
  /// once.
  ///
  /// If [messageIds] is empty, the method returns immediately without
  /// contacting Firestore.
  Future<void> markRead({
    required String matchId,
    required String currentUserId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;

    final updates = messageIds
        .map(
          (id) => ReadUpdate(
            matchId: matchId,
            messageId: id,
            userId: currentUserId,
          ),
        )
        .toList();

    await _commit(updates);
  }
}
