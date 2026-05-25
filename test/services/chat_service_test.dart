/// Unit tests for ChatService — WBS 9.4 + WBS 9.5
///
/// WBS 9.4 tests cover:
///   1. sendMessage('m1', '   ') rejects with EmptyMessageException
///   2. sendMessage('m1', 'x' * 1001) rejects with MessageTooLongException
///   3. Successful send writes doc with all required fields and sentAt as server timestamp
///
/// WBS 9.5 tests cover:
///   1. markRead() calls the batch committer with the correct ReadUpdate records.
///   2. markRead() is idempotent — calling twice produces two identical batch commits.
///   3. markRead() with an empty messageIds list never calls the committer.
///   4. Each ReadUpdate carries the correct matchId, messageId, and userId.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/services/chat_service.dart';

// ---------------------------------------------------------------------------
// Helpers — WBS 9.4
// ---------------------------------------------------------------------------

const _kSendUid = 'user-me';
const _kSendMatchId = 'm1';

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

ChatService _makeSendService(_FakeAdder adder) {
  return ChatService(currentUserId: _kSendUid, messageDocAdder: adder.call);
}

// ---------------------------------------------------------------------------
// Helpers — WBS 9.5
// ---------------------------------------------------------------------------

const _kReadMatchId = 'match-123';
const _kReadUserId = 'user-me';

/// Fake [BatchCommitter] that records every list of [ReadUpdate]s passed to it.
class _FakeCommitter {
  final List<List<ReadUpdate>> calls = [];

  Future<void> call(List<ReadUpdate> updates) async {
    calls.add(List<ReadUpdate>.from(updates));
  }
}

ChatService _makeMarkReadService(_FakeCommitter fake) {
  return ChatService(batchCommitter: fake.call);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // WBS 9.4 — sendMessage()
  // =========================================================================

  group('ChatService.sendMessage() — WBS 9.4', () {
    // ── Test 1: empty / whitespace-only text rejected ─────────────────────────

    test("sendMessage('m1', '   ') throws EmptyMessageException", () async {
      final adder = _FakeAdder();
      final service = _makeSendService(adder);

      expect(
        () => service.sendMessage(_kSendMatchId, '   '),
        throwsA(isA<EmptyMessageException>()),
      );

      // No Firestore write should have happened.
      expect(adder.calls, isEmpty);
    });

    test("sendMessage('m1', '') throws EmptyMessageException", () async {
      final adder = _FakeAdder();
      final service = _makeSendService(adder);

      expect(
        () => service.sendMessage(_kSendMatchId, ''),
        throwsA(isA<EmptyMessageException>()),
      );

      expect(adder.calls, isEmpty);
    });

    // ── Test 2: text > 1000 chars rejected ────────────────────────────────────

    test(
      "sendMessage('m1', 'x' * 1001) throws MessageTooLongException",
      () async {
        final adder = _FakeAdder();
        final service = _makeSendService(adder);

        expect(
          () => service.sendMessage(_kSendMatchId, 'x' * 1001),
          throwsA(isA<MessageTooLongException>()),
        );

        expect(adder.calls, isEmpty);
      },
    );

    test('sendMessage with exactly 1000 chars succeeds (boundary)', () async {
      final adder = _FakeAdder();
      final service = _makeSendService(adder);

      await service.sendMessage(_kSendMatchId, 'x' * 1000);

      expect(adder.calls.length, 1);
      expect(adder.calls.first.data['text'], 'x' * 1000);
    });

    // ── Test 3: successful send writes all required fields ────────────────────

    test(
      'successful send writes doc with all required fields and sentAt as server timestamp',
      () async {
        final adder = _FakeAdder();
        final service = _makeSendService(adder);

        final docId = await service.sendMessage(_kSendMatchId, 'Hello!');

        expect(docId, 'fake-id-1');
        expect(adder.calls.length, 1);

        final call = adder.calls.first;

        // Correct matchId routed to the adder.
        expect(call.matchId, _kSendMatchId);

        final doc = call.data;

        // Required fields per WBS 3.6 schema.
        expect(doc['senderId'], _kSendUid);
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
          equals([_kSendUid]),
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
      final service = _makeSendService(adder);

      await service.sendMessage(_kSendMatchId, '  hi there  ');

      expect(adder.calls.first.data['text'], 'hi there');
    });

    test('sendMessage routes to the correct matchId', () async {
      final adder = _FakeAdder();
      final service = _makeSendService(adder);

      await service.sendMessage('match-abc', 'Test');

      expect(adder.calls.first.matchId, 'match-abc');
    });
  });

  // =========================================================================
  // WBS 9.5 — markRead()
  // =========================================================================

  group('ChatService.markRead() — WBS 9.5', () {
    // ── Test 1 — correct ReadUpdate records are produced ─────────────────────

    test('produces one ReadUpdate per messageId with correct fields', () async {
      final fake = _FakeCommitter();
      final service = _makeMarkReadService(fake);

      await service.markRead(
        matchId: _kReadMatchId,
        currentUserId: _kReadUserId,
        messageIds: ['msg-1', 'msg-2', 'msg-3'],
      );

      expect(
        fake.calls.length,
        equals(1),
        reason: 'committer should be called exactly once',
      );

      final batch = fake.calls.first;
      expect(batch.length, equals(3), reason: 'one ReadUpdate per messageId');

      expect(batch[0].matchId, equals(_kReadMatchId));
      expect(batch[0].messageId, equals('msg-1'));
      expect(batch[0].userId, equals(_kReadUserId));

      expect(batch[1].matchId, equals(_kReadMatchId));
      expect(batch[1].messageId, equals('msg-2'));
      expect(batch[1].userId, equals(_kReadUserId));

      expect(batch[2].matchId, equals(_kReadMatchId));
      expect(batch[2].messageId, equals('msg-3'));
      expect(batch[2].userId, equals(_kReadUserId));
    });

    // ── Test 2 — idempotency ──────────────────────────────────────────────────

    test('is idempotent — calling twice on same ids does not throw and '
        'produces the same batch contents both times', () async {
      final fake = _FakeCommitter();
      final service = _makeMarkReadService(fake);

      await service.markRead(
        matchId: _kReadMatchId,
        currentUserId: _kReadUserId,
        messageIds: ['msg-a', 'msg-b'],
      );

      await service.markRead(
        matchId: _kReadMatchId,
        currentUserId: _kReadUserId,
        messageIds: ['msg-a', 'msg-b'],
      );

      expect(
        fake.calls.length,
        equals(2),
        reason: 'committer called once per markRead invocation',
      );

      expect(
        fake.calls[0],
        equals(fake.calls[1]),
        reason: 'both commits carry the same ReadUpdate records',
      );
    });

    // ── Test 3 — empty messageIds: committer is never called ──────────────────

    test('does not call committer when messageIds is empty', () async {
      final fake = _FakeCommitter();
      final service = _makeMarkReadService(fake);

      await service.markRead(
        matchId: _kReadMatchId,
        currentUserId: _kReadUserId,
        messageIds: [],
      );

      expect(
        fake.calls,
        isEmpty,
        reason: 'no Firestore write should occur for an empty list',
      );
    });

    // ── Test 4 — single message ───────────────────────────────────────────────

    test('works correctly with a single messageId', () async {
      final fake = _FakeCommitter();
      final service = _makeMarkReadService(fake);

      await service.markRead(
        matchId: 'match-xyz',
        currentUserId: 'uid-abc',
        messageIds: ['only-msg'],
      );

      expect(fake.calls.length, equals(1));
      expect(fake.calls.first.length, equals(1));
      expect(fake.calls.first.first.matchId, equals('match-xyz'));
      expect(fake.calls.first.first.messageId, equals('only-msg'));
      expect(fake.calls.first.first.userId, equals('uid-abc'));
    });
  });
}
