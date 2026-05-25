/// Unit tests for WBS 9.5 — Read Receipt Logic (ChatService)
///
/// Tests verify:
///  1. markRead() calls the batch committer with the correct ReadUpdate records.
///  2. markRead() is idempotent — calling twice produces two identical
///     batch commits (arrayUnion makes both no-ops at the Firestore layer).
///  3. markRead() with an empty messageIds list never calls the committer.
///  4. Each ReadUpdate carries the correct matchId, messageId, and userId.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/services/chat_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _kMatchId = 'match-123';
const _kUserId = 'user-me';

/// Fake BatchCommitter that records every list of [ReadUpdate]s passed to it.
///
/// Each call appends the received update list to [calls] so tests can assert
/// on the arguments without touching Firestore.
class _FakeCommitter {
  final List<List<ReadUpdate>> calls = [];

  Future<void> call(List<ReadUpdate> updates) async {
    calls.add(List<ReadUpdate>.from(updates));
  }
}

ChatService _makeService(_FakeCommitter fake) {
  return ChatService(batchCommitter: fake.call);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ChatService.markRead()', () {
    // -----------------------------------------------------------------------
    // Test 1 — correct ReadUpdate records are produced
    // -----------------------------------------------------------------------
    test('produces one ReadUpdate per messageId with correct fields', () async {
      final fake = _FakeCommitter();
      final service = _makeService(fake);

      await service.markRead(
        matchId: _kMatchId,
        currentUserId: _kUserId,
        messageIds: ['msg-1', 'msg-2', 'msg-3'],
      );

      expect(
        fake.calls.length,
        equals(1),
        reason: 'committer should be called exactly once',
      );

      final batch = fake.calls.first;
      expect(batch.length, equals(3), reason: 'one ReadUpdate per messageId');

      expect(batch[0].matchId, equals(_kMatchId));
      expect(batch[0].messageId, equals('msg-1'));
      expect(batch[0].userId, equals(_kUserId));

      expect(batch[1].matchId, equals(_kMatchId));
      expect(batch[1].messageId, equals('msg-2'));
      expect(batch[1].userId, equals(_kUserId));

      expect(batch[2].matchId, equals(_kMatchId));
      expect(batch[2].messageId, equals('msg-3'));
      expect(batch[2].userId, equals(_kUserId));
    });

    // -----------------------------------------------------------------------
    // Test 2 — idempotency: calling twice produces two identical commits
    // -----------------------------------------------------------------------
    test('is idempotent — calling twice on same ids does not throw and '
        'produces the same batch contents both times', () async {
      final fake = _FakeCommitter();
      final service = _makeService(fake);

      // First call
      await service.markRead(
        matchId: _kMatchId,
        currentUserId: _kUserId,
        messageIds: ['msg-a', 'msg-b'],
      );

      // Second call with the same arguments — must not throw
      await service.markRead(
        matchId: _kMatchId,
        currentUserId: _kUserId,
        messageIds: ['msg-a', 'msg-b'],
      );

      expect(
        fake.calls.length,
        equals(2),
        reason: 'committer called once per markRead invocation',
      );

      // Both batches must be identical — arrayUnion makes the second a no-op
      // at the Firestore layer.
      expect(
        fake.calls[0],
        equals(fake.calls[1]),
        reason: 'both commits carry the same ReadUpdate records',
      );
    });

    // -----------------------------------------------------------------------
    // Test 3 — empty messageIds: committer is never called
    // -----------------------------------------------------------------------
    test('does not call committer when messageIds is empty', () async {
      final fake = _FakeCommitter();
      final service = _makeService(fake);

      await service.markRead(
        matchId: _kMatchId,
        currentUserId: _kUserId,
        messageIds: [],
      );

      expect(
        fake.calls,
        isEmpty,
        reason: 'no Firestore write should occur for an empty list',
      );
    });

    // -----------------------------------------------------------------------
    // Test 4 — single message
    // -----------------------------------------------------------------------
    test('works correctly with a single messageId', () async {
      final fake = _FakeCommitter();
      final service = _makeService(fake);

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
