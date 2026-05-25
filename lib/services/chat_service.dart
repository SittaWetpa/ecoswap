/// Chat Service — WBS 9.4
///
/// Implements [sendMessage] which writes a message document to
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
/// - All Firestore I/O is injectable via [MessageDocAdder] so unit tests run
///   without a real Firebase project.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

// ---------------------------------------------------------------------------
// Exceptions
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
// Injectable typedef
// ---------------------------------------------------------------------------

/// Adds one message document to a match's `messages` sub-collection.
///
/// Receives [matchId], [data], and returns the generated document ID.
/// In production this calls [CollectionReference.add]; in tests it is replaced
/// with a fake.
typedef MessageDocAdder =
    Future<String> Function(String matchId, Map<String, dynamic> data);

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

/// Service for WBS 9.4 — Message Send with serverTimestamp.
///
/// Usage (production):
/// ```dart
/// final service = ChatService(currentUserId: FirebaseAuth.instance.currentUser!.uid);
/// await service.sendMessage('matchId-abc', 'Hello!');
/// ```
///
/// Usage (tests — inject fake adder to avoid touching Firebase):
/// ```dart
/// final service = ChatService(
///   currentUserId: 'user-me',
///   messageDocAdder: (matchId, data) async { captured = data; return 'fake-id'; },
/// );
/// await service.sendMessage('m1', 'Hello!');
/// ```
class ChatService {
  final String _currentUserId;
  final MessageDocAdder _addMessageDoc;

  /// Maximum allowed character count for a single message (after trimming).
  static const int maxMessageLength = 1000;

  ChatService({String? currentUserId, MessageDocAdder? messageDocAdder})
    : _currentUserId =
          currentUserId ??
          (firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? ''),
      _addMessageDoc = messageDocAdder ?? _defaultAdder();

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
