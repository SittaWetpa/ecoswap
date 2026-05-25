/// Chat Service — WBS 9.3 + WBS 9.4
///
/// WBS 9.3: Subscribes to the messages subcollection for a given match using
/// `snapshots()`, ordered by `sentAt descending`, capped at 50 messages
/// for the initial load. The stream is consumed by [ChatScreen] via a
/// [StreamBuilder]. The subscription lifecycle is managed inside
/// [ChatScreen.dispose()].
///
/// WBS 9.4: Implements [sendMessage] which writes a message document to
/// `/matches/{matchId}/messages/{messageId}`.
///
/// Design decisions (per WBS 9.4 and 3.6):
/// - [sentAt] is always [FieldValue.serverTimestamp()] to ensure clock-skew-free
///   ordering across devices.
/// - [readBy] is initialised to `[currentUid]` (the sender has already read
///   their own message).
/// - Empty or whitespace-only text is rejected with [EmptyMessageException].
/// - Text longer than 1000 characters (after trimming) is rejected with
///   [MessageTooLongException].
/// - All Firestore I/O is injectable via [MessageStreamFactory] and
///   [MessageDocAdder] so unit tests run without a real Firebase project.
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

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

/// Provides real-time message streaming (WBS 9.3) and message sending (WBS 9.4).
///
/// Usage (production):
/// ```dart
/// final service = ChatService();
/// // Stream messages:
/// final stream = service.messageStream('match-abc');
/// // Send a message:
/// await service.sendMessage('match-abc', 'Hello!');
/// ```
///
/// Usage (tests — inject fakes to avoid touching Firebase):
/// ```dart
/// final controller = StreamController<List<Message>>();
/// final service = ChatService(
///   streamFactory: (_) => controller.stream,
///   currentUserId: 'user-me',
///   messageDocAdder: (matchId, data) async { captured = data; return 'fake-id'; },
/// );
/// ```
class ChatService {
  final MessageStreamFactory _streamFactory;
  // Nullable — resolved lazily in sendMessage() to avoid touching Firebase
  // at construction time (keeps WBS 9.3 stream-only tests Firebase-free).
  final String? _explicitUserId;
  final MessageDocAdder _addMessageDoc;

  /// Maximum allowed character count for a single message (after trimming).
  static const int maxMessageLength = 1000;

  ChatService({
    MessageStreamFactory? streamFactory,
    String? currentUserId,
    MessageDocAdder? messageDocAdder,
  }) : _streamFactory = streamFactory ?? _defaultStreamFactory,
       _explicitUserId = currentUserId,
       _addMessageDoc = messageDocAdder ?? _defaultAdder();

  /// Returns the effective user ID: injected value if provided, otherwise the
  /// Firebase Auth current user's UID (resolved at call time).
  String get _currentUserId =>
      _explicitUserId ??
      firebase_auth.FirebaseAuth.instance.currentUser?.uid ??
      '';

  /// Returns a [Stream<List<Message>>] for the given [matchId].
  ///
  /// Messages are ordered by `sentAt` descending (newest first), limited
  /// to 50 to cap the initial load as required by WBS 9.3.
  Stream<List<Message>> messageStream(String matchId) {
    return _streamFactory(matchId);
  }

  /// Sends a chat message in the match identified by [matchId].
  ///
  /// The [text] is trimmed before any validation.
  ///
  /// Throws [EmptyMessageException] if [text] is blank after trimming.
  /// Throws [MessageTooLongException] if [text] exceeds [maxMessageLength]
  /// characters after trimming.
  ///
  /// On success, returns the Firestore document ID of the written message.
  ///
  /// The written document has the shape required by WBS 3.6:
  /// ```
  /// {
  ///   senderId:  <currentUserId>,
  ///   text:      <trimmed text>,
  ///   sentAt:    FieldValue.serverTimestamp(),
  ///   readBy:    [<currentUserId>],
  /// }
  /// ```
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
}
