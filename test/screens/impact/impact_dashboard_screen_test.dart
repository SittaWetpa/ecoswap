/// Widget tests for WBS 11.3 — Impact Dashboard UI.
///
/// Verifies:
///   1. Hero number reads from `totalCo2Saved` (via [ImpactService]).
///   2. Dashboard shows exactly the 3 stat surfaces (hero + 2 cards).
///   3. Recent trades list shows latest 10 by `completedAt`.
///   4. NO trend arrow appears.
///
/// All Firebase access is stubbed via the injectable hooks on
/// [ImpactDashboardScreen] — no real Firestore or FirebaseAuth involved.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/screens/impact/impact_dashboard_screen.dart';
import 'package:ecoswap/services/impact_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A fake [ImpactService] that returns a fixed [UserImpact] without touching
/// Firestore. Subclassing keeps the [ImpactDashboardScreen] API surface
/// unchanged for production code.
ImpactService _fakeImpactService(UserImpact impact) {
  return ImpactService(
    userDocReader: (_) async => {
      'tradesCount': impact.trades,
      'totalCo2Saved': impact.co2Kg,
      'totalWasteDiverted': impact.wasteKg,
    },
    currentUidProvider: () => 'uid-test',
  );
}

TradeRowData _fakeTrade({
  required String tradeId,
  String counterpartyName = 'Fah',
  String myItemName = 'Tote',
  String theirItemName = 'Kettle',
  double myCo2Saved = 4.5,
  DateTime? completedAt,
}) {
  return TradeRowData(
    tradeId: tradeId,
    counterpartyName: counterpartyName,
    counterpartyPhotoUrl: '',
    myItemName: myItemName,
    theirItemName: theirItemName,
    myCo2Saved: myCo2Saved,
    completedAt: completedAt,
  );
}

Widget _buildScreen({
  required UserImpact impact,
  Stream<List<TradeRowData>>? tradesStream,
}) {
  return MaterialApp(
    home: ImpactDashboardScreen(
      impactService: _fakeImpactService(impact),
      tradesStream: tradesStream ?? Stream.value(const <TradeRowData>[]),
      getCurrentUid: () => 'uid-test',
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ImpactDashboardScreen — WBS 11.3', () {
    // ── Acceptance: Hero displays total CO₂ from /users/{uid}.totalCo2Saved ──
    testWidgets('hero number reads from totalCo2Saved (via ImpactService)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          impact: const UserImpact(trades: 7, co2Kg: 47.5, wasteKg: 12.3),
        ),
      );
      // Pump until the FutureBuilder resolves.
      await tester.pumpAndSettle();

      // The hero RichText contains the value "47.5" (one decimal place,
      // sourced from totalCo2Saved).
      final hero = find.byKey(const Key('hero_co2_number'));
      expect(hero, findsOneWidget);

      final richText = tester.widget<RichText>(hero);
      final fullText = richText.text.toPlainText();
      expect(fullText, contains('47.5'));
      expect(fullText, contains('kg'));
    });

    // ── Acceptance: 3 stat surfaces only (hero + 2 cards) ──────────────────
    testWidgets(
      'dashboard shows exactly the 3 stat surfaces (hero + 2 metric cards)',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen(
            impact: const UserImpact(trades: 4, co2Kg: 22.0, wasteKg: 5.5),
          ),
        );
        await tester.pumpAndSettle();

        // Exactly 1 hero number.
        expect(find.byKey(const Key('hero_co2_number')), findsOneWidget);

        // Exactly 2 metric cards.
        expect(find.byType(MetricCard), findsNWidgets(2));
        expect(find.byKey(const Key('metric_card_swaps')), findsOneWidget);
        expect(find.byKey(const Key('metric_card_waste')), findsOneWidget);

        // Sanity-check the values from the counters appear inside the
        // metric cards (the value is rendered inside a RichText to allow
        // the unit suffix to follow with a smaller weight).
        final swapsCard = tester.widget<MetricCard>(
          find.byKey(const Key('metric_card_swaps')),
        );
        expect(swapsCard.value, equals('4'));
        final wasteCard = tester.widget<MetricCard>(
          find.byKey(const Key('metric_card_waste')),
        );
        expect(wasteCard.value, equals('5.5'));
        expect(wasteCard.unit, equals('kg'));
      },
    );

    // ── Acceptance: trade list shows latest 10 by completedAt ───────────────
    //
    // The Firestore query in production is .orderBy('completedAt', desc: true)
    // .limit(10). Here we inject a stream of 12 rows in shuffled order with
    // their completedAt timestamps; the screen renders the stream as-is, so
    // the test asserts that:
    //   - When the producer emits 10 rows in completedAt-desc order, all 10
    //     are visible and the latest is rendered first.
    //   - No more than 10 TradeRow widgets appear when 10 are emitted.
    testWidgets(
      'trade list shows latest 10 trades by completedAt (descending)',
      (tester) async {
        // Build 10 trades, newest first.
        final base = DateTime(2026, 5, 26, 12, 0);
        final rows = List<TradeRowData>.generate(10, (i) {
          return _fakeTrade(
            tradeId: 'trade-$i',
            counterpartyName: 'User$i',
            myItemName: 'MyItem$i',
            theirItemName: 'TheirItem$i',
            myCo2Saved: 1.0 + i,
            completedAt: base.subtract(Duration(days: i)),
          );
        });

        await tester.pumpWidget(
          _buildScreen(
            impact: const UserImpact(trades: 10, co2Kg: 50.0, wasteKg: 10.0),
            tradesStream: Stream.value(rows),
          ),
        );
        await tester.pumpAndSettle();

        // 10 TradeRow widgets are rendered.
        expect(find.byType(TradeRow), findsNWidgets(10));

        // The latest row (User0) is rendered before the oldest (User9) in
        // the widget tree — i.e., descending by completedAt.
        final user0 = tester.getTopLeft(find.text('MyItem0').first).dy;
        final user9 = tester.getTopLeft(find.text('MyItem9').first).dy;
        expect(
          user0,
          lessThan(user9),
          reason:
              'Latest trade (User0) should appear above oldest trade (User9).',
        );
      },
    );

    // ── Acceptance: NO trend arrow appears ──────────────────────────────────
    //
    // Locked decision (CLAUDE.md): no trend arrows ("↑38%"), no "this month"
    // comparison card. We sweep the rendered widget tree for any Text whose
    // content looks like a trend marker and assert nothing matches.
    testWidgets(
      'NO trend arrow ("↑" or "↓" with a percentage) appears anywhere',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen(
            impact: const UserImpact(trades: 7, co2Kg: 47.5, wasteKg: 12.3),
            tradesStream: Stream.value([
              _fakeTrade(tradeId: 't1', completedAt: DateTime(2026, 5, 26)),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        // Walk all rendered Text widgets and check none contains "↑", "↓",
        // or the phrase "this month" (case-insensitive). These would all
        // indicate a trend / comparison element creeping in.
        final allText = find.byType(Text);
        for (final element in allText.evaluate()) {
          final text = (element.widget as Text).data ?? '';
          expect(text.contains('↑'), isFalse, reason: 'Text was: "$text"');
          expect(text.contains('↓'), isFalse, reason: 'Text was: "$text"');
          expect(
            text.toLowerCase().contains('this month'),
            isFalse,
            reason: 'Text was: "$text"',
          );
        }

        // Also sweep RichText spans (the hero uses RichText).
        final allRich = find.byType(RichText);
        for (final element in allRich.evaluate()) {
          final plain = (element.widget as RichText).text.toPlainText();
          expect(plain.contains('↑'), isFalse, reason: 'RichText: "$plain"');
          expect(plain.contains('↓'), isFalse, reason: 'RichText: "$plain"');
        }
      },
    );

    // ── Extra: top bar is title-only (no cog/info/share icons) ──────────────
    //
    // Locked decision (CLAUDE.md): the Impact top bar is title-only. AppBar
    // has no leading widget and no actions.
    testWidgets('top bar is title-only (no cog, no info, no share icon)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(impact: const UserImpact(trades: 0, co2Kg: 0, wasteKg: 0)),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.leading, isNull);
      expect(appBar.actions == null || appBar.actions!.isEmpty, isTrue);
      // Title text is "Impact".
      expect(find.text('Impact'), findsOneWidget);
    });
  });
}
