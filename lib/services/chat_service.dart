/// ChatService — WBS 9.3 Firestore Real-Time Listener
///
/// Subscribes to the messages subcollection for a given match using
/// `snapshots()`, ordered by `sentAt descending`, capped at 50 messages
/// for the initial load.
///
/// The stream is consumed by [ChatScreen] via a [StreamBuilder]. The
/// subscription lifecycle is managed inside [ChatScreen.dispose()].
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ecoswap/models/message.dart';

// ---------------------------------------------------------------------------
// Injectable typedef
// ---------------------------------------------------------------------------

/// Returns a live stream of messages for the given matchId.
///
/// Production: delegates to Firestore.
/// Tests: injected with a [StreamController] backed stream.
typedef MessageStreamFactory = Stream<List<Message>> Function(String matchId);

// ---------------------------------------------------------------------------
// ChatService
// ---------------------------------------------------------------------------

/// Provides real-time message streaming for a match's messages subcollection.
///
/// Usage (production):
/// ```dart
/// final service = ChatService();
/// final stream = service.messageStream('match-abc');
/// ```
///
/// Usage (tests):
/// ```dart
/// final controller = StreamController<List<Message>>();
/// final service = ChatService(
///   streamFactory: (_) => controller.stream,
/// );
/// ```
class ChatService {
  final MessageStreamFactory _streamFactory;

  ChatService({MessageStreamFactory? streamFactory})
    : _streamFactory = streamFactory ?? _defaultStreamFactory;

  /// Returns a [Stream<List<Message>>] for the given [matchId].
  ///
  /// Messages are ordered by `sentAt` descending (newest first), limited
  /// to 50 to cap the initial load as required by WBS 9.3.
  Stream<List<Message>> messageStream(String matchId) {
    return _streamFactory(matchId);
  }
}

// ---------------------------------------------------------------------------
// Default Firestore implementation
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
