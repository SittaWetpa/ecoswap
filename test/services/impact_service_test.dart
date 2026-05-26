/// Unit tests for WBS 11.2 — Impact Aggregation via Denormalized Counters.
///
/// Verifies that [ImpactService.getCurrentUserImpact] reads from a single
/// `/users/{uid}` document and maps the three denormalized counters
/// (`tradesCount`, `totalCo2Saved`, `totalWasteDiverted`) onto the
/// `{ trades, co2Kg, wasteKg }` return shape.
///
/// The writer-side guarantee (10.6's transaction increments these fields
/// atomically with the trade write) is exercised in the integration test
/// at `integration_test/impact_service_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/services/impact_service.dart';

// ---------------------------------------------------------------------------
// Helpers — fake UserDocReader that records calls so tests can assert
// on the read shape (single-document read, no aggregation).
// ---------------------------------------------------------------------------

class _FakeReader {
  final Map<String, Map<String, dynamic>?> _docs;
  final List<String> reads = [];

  _FakeReader(this._docs);

  Future<Map<String, dynamic>?> call(String uid) async {
    reads.add(uid);
    return _docs[uid];
  }
}

ImpactService _serviceFor(String uid, _FakeReader reader) {
  return ImpactService(
    userDocReader: reader.call,
    currentUidProvider: () => uid,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ImpactService.getCurrentUserImpact() — WBS 11.2', () {
    // ── Test 1 (from WBS Testing section): tradesCount: 3 → trades: 3 ───────
    test(
      'returns trades: 3 when the user document has tradesCount: 3',
      () async {
        final reader = _FakeReader({
          'uid-ploy': {
            'tradesCount': 3,
            'totalCo2Saved': 12.5,
            'totalWasteDiverted': 1.8,
          },
        });
        final service = _serviceFor('uid-ploy', reader);

        final impact = await service.getCurrentUserImpact();

        expect(impact.trades, equals(3));
        expect(impact.co2Kg, equals(12.5));
        expect(impact.wasteKg, equals(1.8));
      },
    );

    // ── Test 2: single document read — no aggregation query ──────────────────
    test(
      'reads exactly one document (/users/{uid}), never an aggregation query',
      () async {
        final reader = _FakeReader({
          'uid-fah': {
            'tradesCount': 5,
            'totalCo2Saved': 42.0,
            'totalWasteDiverted': 6.0,
          },
        });
        final service = _serviceFor('uid-fah', reader);

        await service.getCurrentUserImpact();

        expect(reader.reads, equals(['uid-fah']));
      },
    );

    // ── Test 3: cold-start — user doc exists but has no counter fields ──────
    test(
      'returns zeros when the user document is missing counter fields',
      () async {
        final reader = _FakeReader({
          'uid-newbie': {
            // Brand-new user — fresh from signup, no trades yet. Auth signup
            // (4.1) writes counters: 0, but tolerate a doc that somehow lacks
            // them rather than throwing.
            'email': 'newbie@example.com',
            'displayName': '',
          },
        });
        final service = _serviceFor('uid-newbie', reader);

        final impact = await service.getCurrentUserImpact();

        expect(impact, equals(UserImpact.zero));
      },
    );

    // ── Test 4: cold-start — user document does not exist at all ────────────
    test('returns zeros when the user document does not exist', () async {
      final reader = _FakeReader({'uid-missing': null});
      final service = _serviceFor('uid-missing', reader);

      final impact = await service.getCurrentUserImpact();

      expect(impact, equals(UserImpact.zero));
    });

    // ── Test 5: integer/float coercion ──────────────────────────────────────
    test(
      'coerces numeric types (int → double, double → int) defensively',
      () async {
        final reader = _FakeReader({
          'uid-mixed': {
            // tradesCount stored as double — should coerce to int.
            'tradesCount': 7.0,
            // totalCo2Saved stored as int — should coerce to double.
            'totalCo2Saved': 30,
            // totalWasteDiverted stored as double — passes through.
            'totalWasteDiverted': 2.5,
          },
        });
        final service = _serviceFor('uid-mixed', reader);

        final impact = await service.getCurrentUserImpact();

        expect(impact.trades, equals(7));
        expect(impact.co2Kg, equals(30.0));
        expect(impact.wasteKg, equals(2.5));
      },
    );

    // ── Test 6: no signed-in user → NotSignedInException ────────────────────
    test('throws NotSignedInException when no user is signed in', () async {
      final reader = _FakeReader({});
      final service = ImpactService(
        userDocReader: reader.call,
        currentUidProvider: () => null,
      );

      expect(
        () => service.getCurrentUserImpact(),
        throwsA(isA<NotSignedInException>()),
      );

      // Guard: the reader must not be invoked when no uid is resolvable.
      expect(reader.reads, isEmpty);
    });

    // ── Test 7: empty uid is also treated as not signed in ──────────────────
    test('throws NotSignedInException when the current uid is empty', () async {
      final reader = _FakeReader({});
      final service = ImpactService(
        userDocReader: reader.call,
        currentUidProvider: () => '',
      );

      expect(
        () => service.getCurrentUserImpact(),
        throwsA(isA<NotSignedInException>()),
      );
      expect(reader.reads, isEmpty);
    });
  });

  group('UserImpact value semantics', () {
    test('two impacts with the same values are equal', () {
      const a = UserImpact(trades: 3, co2Kg: 12.5, wasteKg: 1.8);
      const b = UserImpact(trades: 3, co2Kg: 12.5, wasteKg: 1.8);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('UserImpact.zero is all zeros', () {
      expect(UserImpact.zero.trades, equals(0));
      expect(UserImpact.zero.co2Kg, equals(0));
      expect(UserImpact.zero.wasteKg, equals(0));
    });
  });
}
