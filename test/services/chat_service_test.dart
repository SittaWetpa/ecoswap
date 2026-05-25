/// Unit tests for WBS 9.4 — Message Send with serverTimestamp
///
/// Covers all four tests listed in the WBS entry:
///   1. sendMessage('m1', '   ') rejects with EmptyMessageException
///   2. sendMessage('m1', 'x' * 1001) rejects with MessageTooLongException
///   3. Successful send writes doc with all required fields and sentAt as server timestamp
///   4. Optimistic UI shows the message before Firestore round-trip completes
///      (widget test — see test/screens/chats/chat_service_optimistic_test.dart)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/services/chat_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _currentUid = 'user-me';
const _matchId = 'm1';

/// Fake [MessageDocAdder] that captures every call.
class _FakeAdder {
  int _callCount = 0;
  final List<({String matchId, Map<String, dynamic> data})> calls = [];

  Future<String> call(String matchId, Map<String, dynamic> data) async {
    _callCount++;
    calls.add((matchId: matchId, data: Map<String, dynamic>.from(data)));
    return 'fake-id-$_callCount';
  }
}

ChatService _makeService(_FakeAdder adder) {
  return ChatService(
    currentUserId: _currentUid,
    messageDocAdder: adder.call,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatService.sendMessage() — WBS 9.4', () {
    // ── Test 1: empty / whitespace-only text rejected ─────────────────────────

    test(
      "sendMessage('m1', '   ') throws EmptyMessageException",
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        expect(
          () => service.sendMessage(_matchId, '   '),
          throwsA(isA<EmptyMessageException>()),
        );

        // No Firestore write should have happened.
        expect(adder.calls, isEmpty);
      },
    );

    test(
      "sendMessage('m1', '') throws EmptyMessageException",
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        expect(
          () => service.sendMessage(_matchId, ''),
          throwsA(isA<EmptyMessageException>()),
        );

        expect(adder.calls, isEmpty);
      },
    );

    // ── Test 2: text > 1000 chars rejected ────────────────────────────────────

    test(
      "sendMessage('m1', 'x' * 1001) throws MessageTooLongException",
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        expect(
          () => service.sendMessage(_matchId, 'x' * 1001),
          throwsA(isA<MessageTooLongException>()),
        );

        expect(adder.calls, isEmpty);
      },
    );

    test(
      'sendMessage with exactly 1000 chars succeeds (boundary)',
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        await service.sendMessage(_matchId, 'x' * 1000);

        expect(adder.calls.length, 1);
        expect(adder.calls.first.data['text'], 'x' * 1000);
      },
    );

    // ── Test 3: successful send writes all required fields ────────────────────

    test(
      'successful send writes doc with all required fields and sentAt as server timestamp',
      () async {
        final adder = _FakeAdder();
        final service = _makeService(adder);

        final docId = await service.sendMessage(_matchId, 'Hello!');

        expect(docId, 'fake-id-1');
        expect(adder.calls.length, 1);

        final call = adder.calls.first;

        // Correct matchId routed to the adder.
        expect(call.matchId, _matchId);

        final doc = call.data;

        // Required fields per WBS 3.6 schema.
        expect(doc['senderId'], _currentUid);
        expect(doc['text'], 'Hello!');

        // sentAt must be a FieldValue (server timestamp), NOT a client DateTime.
        expect(
          doc['sentAt'],
          isA<FieldValue>(),
          reason:
              'sentAt must be FieldValue.serverTimestamp(), not a client-side DateTime',
        );

        // readBy initialised to [currentUid].
        expect(
          doc['readBy'],
          equals([_currentUid]),
          reason: 'readBy must contain exactly the sender uid at send time',
        );

        // Exactly the 4 locked fields, nothing extra.
        expect(
          doc.keys.toSet(),
          equals({'senderId', 'text', 'sentAt', 'readBy'}),
          reason: 'Message doc must have exactly the 4 fields from WBS 3.6',
        );
      },
    );

    test('text is trimmed before writing', () async {
      final adder = _FakeAdder();
      final service = _makeService(adder);

      await service.sendMessage(_matchId, '  hi there  ');

      expect(adder.calls.first.data['text'], 'hi there');
    });

    test('sendMessage routes to the correct matchId', () async {
      final adder = _FakeAdder();
      final service = _makeService(adder);

      await service.sendMessage('match-abc', 'Test');

      expect(adder.calls.first.matchId, 'match-abc');
    });
  });
}
