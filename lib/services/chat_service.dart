/// ChatService — WBS 9.3 + WBS 9.5
///
/// WBS 9.3: [messageStream] subscribes to the messages subcollection for a
/// given match, ordered by `sentAt` descending, capped at 50 messages.
///
/// WBS 9.5: [markRead] batch-updates the `readBy` array on message documents,
/// appending [currentUserId] to each message in [messageIds].
/// Uses `WriteBatch` + `FieldValue.arrayUnion` for idempotency.
///
/// All Firestore I/O is injectable so unit tests run without a real Firebase
/// project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ecoswap/models/message.dart';

// ---------------------------------------------------------------------------
// WBS 9.5 — ReadUpdate data class
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
// Injectable typedefs
// ---------------------------------------------------------------------------

/// Returns a live stream of messages for the given matchId.
///
/// Production: delegates to Firestore.
/// Tests: injected with a [StreamController] backed stream.
typedef MessageStreamFactory = Stream<List<Message>> Function(String matchId);

/// Commits a batch of readBy updates to Firestore.
///
/// Receives a list of [ReadUpdate] records (each carrying the document path
/// and the user ID to append) and executes a single [WriteBatch] commit.
///
/// In production this calls real Firestore; in tests it is replaced with a
/// fake that captures calls without touching Firebase.
typedef BatchCommitter = Future<void> Function(List<ReadUpdate> updates);

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

/// Provides real-time message streaming (WBS 9.3) and read-receipt writes
/// (WBS 9.5) for a match's messages subcollection.
///
/// Usage (production):
/// ```dart
/// final service = ChatService();
/// // stream messages
/// final stream = service.messageStream('match-abc');
/// // mark messages read
/// await service.markRead(
///   matchId: 'match-abc',
///   currentUserId: FirebaseAuth.instance.currentUser!.uid,
///   messageIds: ['msg1', 'msg2'],
/// );
/// ```
///
/// Usage (tests — inject fakes):
/// ```dart
/// final controller = StreamController<List<Message>>();
/// final captured = <List<ReadUpdate>>[];
/// final service = ChatService(
///   streamFactory: (_) => controller.stream,
///   batchCommitter: (updates) async { captured.add(updates); },
/// );
/// ```
class ChatService {
  final MessageStreamFactory _streamFactory;
  final BatchCommitter _commit;

  ChatService({
    MessageStreamFactory? streamFactory,
    BatchCommitter? batchCommitter,
  }) : _streamFactory = streamFactory ?? _defaultStreamFactory,
       _commit = batchCommitter ?? _defaultCommitter();

  // -------------------------------------------------------------------------
  // WBS 9.3 — Real-time message stream
  // -------------------------------------------------------------------------

  /// Returns a [Stream<List<Message>>] for the given [matchId].
  ///
  /// Messages are ordered by `sentAt` descending (newest first), limited
  /// to 50 to cap the initial load as required by WBS 9.3.
  Stream<List<Message>> messageStream(String matchId) {
    return _streamFactory(matchId);
  }

  // -------------------------------------------------------------------------
  // WBS 9.5 — Read receipt writes
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

// ---------------------------------------------------------------------------
// Default Firestore implementations
// ---------------------------------------------------------------------------

Stream<List<Message>> _defaultStreamFactory(String matchId) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Message.fromJson(doc.data(), id: doc.id))
            .toList(),
      );
}

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
