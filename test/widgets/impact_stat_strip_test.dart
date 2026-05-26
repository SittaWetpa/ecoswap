/// Widget tests for WBS 11.4 — Impact Stat Strip.
///
/// Verifies the two acceptance-coupled tests called out in the WBS entry:
///   1. The strip renders 3 stat values.
///   2. The values match `ImpactService.getCurrentUserImpact()` output.
///
/// Also verifies the locked-decision guardrails: no trend arrows, no "this
/// month" / comparison copy, integer formatting for swaps, one-decimal
/// formatting for CO₂ and waste.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/services/impact_service.dart';
import 'package:ecoswap/widgets/impact_stat_strip.dart';

// ---------------------------------------------------------------------------
// Fake ImpactService — never touches Firebase.
// ---------------------------------------------------------------------------

ImpactService _fakeService(UserImpact impact) {
  return ImpactService(
    userDocReader: (uid) async => {
      'tradesCount': impact.trades,
      'totalCo2Saved': impact.co2Kg,
      'totalWasteDiverted': impact.wasteKg,
    },
    currentUidProvider: () => 'uid-test',
  );
}

ImpactService _throwingService() {
  return ImpactService(
    userDocReader: (uid) async => throw StateError('boom'),
    currentUidProvider: () => 'uid-test',
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  // -------------------------------------------------------------------------
  // WBS 11.4 Testing requirement 1: strip renders 3 stat values
  // -------------------------------------------------------------------------
  group('ImpactStatStrip — renders 3 stat values', () {
    testWidgets('renders exactly 3 SummaryStat widgets', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(
              trades: 7,
              co2Kg: 47.5,
              wasteKg: 12.3,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SummaryStat), findsNWidgets(3));
    });

    testWidgets('strip container has the impactSummary key', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(trades: 0, co2Kg: 0, wasteKg: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('impactSummary')), findsOneWidget);
    });

    testWidgets('renders all 3 labels: Swaps, kg CO₂, kg waste', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(
              trades: 1,
              co2Kg: 1.0,
              wasteKg: 1.0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Swaps'), findsOneWidget);
      expect(find.text('kg CO₂'), findsOneWidget);
      expect(find.text('kg waste'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // WBS 11.4 Testing requirement 2:
  //   values match `getCurrentUserImpact()` output
  // -------------------------------------------------------------------------
  group('ImpactStatStrip — values match getCurrentUserImpact() output', () {
    testWidgets(
      'reads from the injected ImpactService and renders its values',
      (tester) async {
        final service = _fakeService(
          const UserImpact(trades: 3, co2Kg: 18.0, wasteKg: 4.2),
        );

        await tester.pumpWidget(_wrap(ImpactStatStrip(impactService: service)));

        // First frame: loading placeholder (em-dashes). Pump to let the
        // future resolve.
        await tester.pump();
        await tester.pump();

        // Verify the service-derived values appear.
        // Swaps: integer formatting.
        expect(find.text('3'), findsOneWidget);
        // CO₂: one decimal.
        expect(find.text('18.0'), findsOneWidget);
        // Waste: one decimal.
        expect(find.text('4.2'), findsOneWidget);
      },
    );

    testWidgets(
      'refreshes the seed value with the service value when both are wired',
      (tester) async {
        final service = _fakeService(
          const UserImpact(trades: 9, co2Kg: 65.0, wasteKg: 20.5),
        );

        await tester.pumpWidget(
          _wrap(
            ImpactStatStrip(
              impactService: service,
              // Stale seed value the strip should overwrite after the
              // service call resolves.
              initialImpact: const UserImpact(trades: 0, co2Kg: 0, wasteKg: 0),
            ),
          ),
        );

        // Pump until the service future resolves and the rebuild lands.
        await tester.pump();
        await tester.pump();

        // The strip must reflect the service value, not the stale seed.
        expect(find.text('9'), findsOneWidget);
        expect(find.text('65.0'), findsOneWidget);
        expect(find.text('20.5'), findsOneWidget);
        // The stale seed value must NOT be visible any more.
        expect(find.text('0.0'), findsNothing);
      },
    );

    testWidgets('integer formatting for swaps (no decimals)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(trades: 12, co2Kg: 0, wasteKg: 0),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('12'), findsOneWidget);
      expect(
        find.text('12.0'),
        findsNothing,
        reason: 'Swaps must be an integer with no decimals',
      );
    });

    testWidgets('one-decimal formatting for CO₂ and waste', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(trades: 0, co2Kg: 5, wasteKg: 1),
          ),
        ),
      );
      await tester.pump();

      // toStringAsFixed(1) on a whole number produces a trailing ".0".
      expect(find.text('5.0'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);
    });

    testWidgets('falls back to seed (or zero) when the service throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            impactService: _throwingService(),
            initialImpact: const UserImpact(
              trades: 4,
              co2Kg: 2.5,
              wasteKg: 0.8,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Seed values are preserved when the service errors.
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('0.8'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Locked-decision guardrails
  // -------------------------------------------------------------------------
  group('ImpactStatStrip — no out-of-scope UI elements', () {
    testWidgets('no trend arrows, no "this month", no comparison copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(
              trades: 7,
              co2Kg: 47.5,
              wasteKg: 12.3,
            ),
          ),
        ),
      );
      await tester.pump();

      // No trend-arrow icons.
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
      expect(find.byIcon(Icons.trending_up), findsNothing);
      expect(find.byIcon(Icons.trending_down), findsNothing);

      // No comparison-copy strings.
      expect(find.textContaining('This month'), findsNothing);
      expect(find.textContaining('this month'), findsNothing);
      expect(find.textContaining('↑'), findsNothing);
      expect(find.textContaining('↓'), findsNothing);
      expect(find.textContaining('vs'), findsNothing);
    });

    testWidgets('uses "Swaps" not "Trades" in the UI label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImpactStatStrip(
            initialImpact: const UserImpact(
              trades: 7,
              co2Kg: 47.5,
              wasteKg: 12.3,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Swaps'), findsOneWidget);
      expect(
        find.text('Trades'),
        findsNothing,
        reason: 'User-facing label must be "Swaps", not "Trades"',
      );
    });
  });
}
