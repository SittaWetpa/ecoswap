/// ChatService — WBS 9.3 + WBS 9.4 + WBS 9.5
///
/// WBS 9.3: [messageStream] subscribes to the messages subcollection for a
/// given match, ordered by `sentAt` descending, capped at 50 messages.
///
/// WBS 9.4: [sendMessage] writes a message document to
/// `/matches/{matchId}/messages/{messageId}`. Uses [FieldValue.serverTimestamp]
/// for sentAt and initialises `readBy` to `[currentUid]`.
/// Throws [EmptyMessageException] / [MessageTooLongException] on invalid input.
///
/// WBS 9.5: [markRead] batch-updates the `readBy` array on message documents,
/// appending [currentUserId] to each message in [messageIds].
/// Uses `WriteBatch` + `FieldValue.arrayUnion` for idempotency.
///
/// All Firestore I/O is injectable so unit tests run without a real Firebase
/// project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:ecoswap/models/message.dart';

// ---------------------------------------------------------------------------
// Exceptions (WBS 9.4)
// ---------------------------------------------------------------------------

/// Thrown by [ChatService.sendMessage] when the trimmed message text is empty.
class EmptyMessageException implements Exception {
  final String message;
  const EmptyMessageException([
    this.message = 'Message text must not be empty or whitespace-only.',
  ]);

  @override
  String toString() => 'EmptyMessageException: $message';
}

/// Thrown by [ChatService.sendMessage] when the trimmed message exceeds 1000
/// characters.
class MessageTooLongException implements Exception {
  final String message;
  const MessageTooLongException([
    this.message = 'Message must be 1000 characters or fewer.',
  ]);

  @override
  String toString() => 'MessageTooLongException: $message';
}

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

/// Adds one message document to a match's `messages` sub-collection.
///
/// Receives [matchId], [data], and returns the generated document ID.
/// In production this calls [CollectionReference.add]; in tests it is replaced
/// with a fake.
typedef MessageDocAdder =
    Future<String> Function(String matchId, Map<String, dynamic> data);

/// Commits a batch of readBy updates to Firestore.
///
/// Receives a list of [ReadUpdate] records (each carrying the document path
/// and the user ID to append) and executes a single [WriteBatch] commit.
///
/// In production this calls real Firestore; in tests it is replaced with a
/// fake that captures calls without touching Firebase.
typedef BatchCommitter = Future<void> Function(List<ReadUpdate> updates);

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

/// Returns the default [MessageDocAdder] that writes to the real Firestore
/// instance.
MessageDocAdder _defaultAdder() {
  return (String matchId, Map<String, dynamic> data) async {
    final ref = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('messages')
        .add(data);
    return ref.id;
  };
}

/// Returns the default [BatchCommitter] that writes readBy updates to the real
/// Firestore instance using a [WriteBatch].
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

/// Provides real-time message streaming (WBS 9.3), message sending (WBS 9.4),
/// and read-receipt writes (WBS 9.5) for a match's messages subcollection.
class ChatService {
  final MessageStreamFactory _streamFactory;
  // Nullable — resolved lazily in sendMessage() to avoid touching Firebase
  // at construction time (keeps WBS 9.3 stream-only tests Firebase-free).
  final String? _explicitUserId;
  final MessageDocAdder _addMessageDoc;
  final BatchCommitter _commit;

  /// Maximum allowed character count for a single message (after trimming).
  static const int maxMessageLength = 1000;

  ChatService({
    MessageStreamFactory? streamFactory,
    String? currentUserId,
    MessageDocAdder? messageDocAdder,
    BatchCommitter? batchCommitter,
  }) : _streamFactory = streamFactory ?? _defaultStreamFactory,
       _explicitUserId = currentUserId,
       _addMessageDoc = messageDocAdder ?? _defaultAdder(),
       _commit = batchCommitter ?? _defaultCommitter();

  /// Returns the effective user ID: injected value if provided, otherwise the
  /// Firebase Auth current user's UID (resolved at call time).
  String get _currentUserId =>
      _explicitUserId ??
      firebase_auth.FirebaseAuth.instance.currentUser?.uid ??
      '';

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
  // WBS 9.4 — Message send
  // -------------------------------------------------------------------------

  /// Sends a chat message in the match identified by [matchId].
  ///
  /// Throws [EmptyMessageException] if [text] is blank after trimming.
  /// Throws [MessageTooLongException] if [text] exceeds [maxMessageLength].
  ///
  /// On success, returns the Firestore document ID of the written message.
  Future<String> sendMessage(String matchId, String text) async {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      throw const EmptyMessageException();
    }

    if (trimmed.length > maxMessageLength) {
      throw const MessageTooLongException();
    }

    final data = <String, dynamic>{
      'senderId': _currentUserId,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      'readBy': [_currentUserId],
    };

    return _addMessageDoc(matchId, data);
  }

  // -------------------------------------------------------------------------
  // WBS 9.5 — Read receipt writes
  // -------------------------------------------------------------------------

  /// Marks [messageIds] as read by [currentUserId] within [matchId].
  ///
  /// Appends [currentUserId] to each message's `readBy` array using
  /// `FieldValue.arrayUnion`, which guarantees idempotency.
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
