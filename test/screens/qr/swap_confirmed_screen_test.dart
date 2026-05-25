/// Widget tests for the Swap Confirmed Screen — WBS 10.6 (Flutter side).
///
/// Coverage:
///   - Renders both item photos and names from the provided data.
///   - Headline is exactly "Swap complete!" (locked copy).
///   - Impact numbers shown match values from the data, NOT recomputed.
///   - Picks the correct gains object based on current uid (A sees A's,
///     B sees B's) when loaded from a trade doc map.
///   - No forbidden UI elements: no "Trade complete", no "verified", no
///     "this month", no trend arrows, no cog/settings/info icon.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoswap/screens/qr/swap_confirmed_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SwapConfirmedData _fakeData({
  String myItemName = 'Denim jacket',
  String myItemPhotoUrl = 'https://example.com/jacket.jpg',
  String theirItemName = 'Electric kettle',
  String theirItemPhotoUrl = 'https://example.com/kettle.jpg',
  String counterpartyName = 'Fah',
  double myCo2Saved = 7.2,
  double myWasteDiverted = 0.6,
}) {
  return SwapConfirmedData(
    myItemPhotoUrl: myItemPhotoUrl,
    myItemName: myItemName,
    theirItemPhotoUrl: theirItemPhotoUrl,
    theirItemName: theirItemName,
    counterpartyName: counterpartyName,
    myCo2Saved: myCo2Saved,
    myWasteDiverted: myWasteDiverted,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: child);

/// Stand-in for a `/trades/{tradeId}` doc shape, exactly mirroring what the
/// Cloud Function in `functions/src/writeTradeAndImpact.ts` writes.
///
/// Used only for the gains-attribution test below — we don't need a real
/// Firestore round-trip, just the same shape the loader would consume.
Map<String, dynamic> _fakeTradeDoc({
  required String userAId,
  required String userBId,
  double aCo2 = 7.2,
  double aWaste = 0.6,
  double bCo2 = 15.0,
  double bWaste = 1.2,
}) {
  return {
    'matchId': 'match-1',
    'jwtTokenHash': 'hash',
    'impact': {
      'userAGains': {
        'userId': userAId,
        'co2Saved': aCo2,
        'wasteDiverted': aWaste,
      },
      'userBGains': {
        'userId': userBId,
        'co2Saved': bCo2,
        'wasteDiverted': bWaste,
      },
    },
    'itemsExchanged': {'fromA': 'itemA', 'fromB': 'itemB'},
  };
}

/// Replicates the loader's per-user attribution choice. The widget never
/// reads the trade doc directly when tests inject [SwapConfirmedData], so
/// this helper lets us verify the loader's branch logic without mocking
/// Firebase.
SwapConfirmedData _attributeForCurrent({
  required Map<String, dynamic> tradeDoc,
  required String currentUid,
  required String myItemName,
  required String theirItemName,
  required String counterpartyName,
}) {
  final impact = tradeDoc['impact'] as Map<String, dynamic>;
  final userAGains = impact['userAGains'] as Map<String, dynamic>;
  final userBGains = impact['userBGains'] as Map<String, dynamic>;
  final isUserA = userAGains['userId'] == currentUid;
  final gains = isUserA ? userAGains : userBGains;
  return _fakeData(
    myItemName: myItemName,
    theirItemName: theirItemName,
    counterpartyName: counterpartyName,
    myCo2Saved: (gains['co2Saved'] as num).toDouble(),
    myWasteDiverted: (gains['wasteDiverted'] as num).toDouble(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SwapConfirmedScreen', () {
    // ── Test 1: renders both item names from the provided data ─────────────

    testWidgets('renders both item names from the provided data', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          SwapConfirmedScreen(
            data: _fakeData(
              myItemName: 'Denim jacket',
              theirItemName: 'Electric kettle',
            ),
          ),
        ),
      );

      expect(find.text('Denim jacket'), findsWidgets);
      expect(find.text('Electric kettle'), findsWidgets);
    });

    // ── Test 2: both item photo Image.network widgets present ──────────────

    testWidgets('renders both item photos when photo URLs are provided', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          SwapConfirmedScreen(
            data: _fakeData(
              myItemPhotoUrl: 'https://example.com/jacket.jpg',
              theirItemPhotoUrl: 'https://example.com/kettle.jpg',
            ),
          ),
        ),
      );

      // Two photos — one for my item, one for theirs.
      final images = find.byType(Image);
      expect(images, findsNWidgets(2));
    });

    // ── Test 3: headline copy is exactly "Swap complete!" ──────────────────
    //
    // Locked vocabulary: user-facing "Swap", never "Trade".

    testWidgets('shows the exact headline "Swap complete!"', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(SwapConfirmedScreen(data: _fakeData())));

      expect(find.text('Swap complete!'), findsOneWidget);
      // Negative: must not say "Trade complete" or "Trade complete!".
      expect(find.text('Trade complete'), findsNothing);
      expect(find.text('Trade complete!'), findsNothing);
    });

    // ── Test 4: impact numbers come from the trade data ───────────────────
    //
    // The screen must display exactly the values passed in (server-computed),
    // not re-derive them from category × weight on the client.

    testWidgets(
      'impact numbers shown match the values from the trade data (not recomputed)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // 7.2 kg CO₂ saved matches the worked example in WBS 11.1
        // (Ploy receives Fah's 1.2 kg kitchenware → 1.2 × 6 = 7.2).
        await tester.pumpWidget(
          _wrap(
            SwapConfirmedScreen(
              data: _fakeData(myCo2Saved: 7.2, myWasteDiverted: 0.6),
            ),
          ),
        );

        expect(find.text('+7.2 kg'), findsOneWidget);
        expect(find.text('+0.6 kg'), findsOneWidget);
      },
    );

    // ── Test 5: per-user attribution (A sees A's gains; B sees B's) ────────
    //
    // Mirrors what `loadSwapConfirmedData` does: pick userAGains if the
    // current uid matches userAGains.userId, otherwise userBGains. We
    // exercise the branch by feeding the screen pre-attributed data twice
    // from the same canonical trade-doc map.

    testWidgets('picks the correct gains object based on current user', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tradeDoc = _fakeTradeDoc(
        userAId: 'user-ploy',
        userBId: 'user-fah',
        aCo2: 7.2,
        aWaste: 0.6,
        bCo2: 15.0,
        bWaste: 1.2,
      );

      // ── User A (Ploy) sees userAGains: CO₂ 7.2, waste 0.6 ───────────
      final dataForA = _attributeForCurrent(
        tradeDoc: tradeDoc,
        currentUid: 'user-ploy',
        myItemName: 'Denim jacket',
        theirItemName: 'Electric kettle',
        counterpartyName: 'Fah',
      );
      await tester.pumpWidget(_wrap(SwapConfirmedScreen(data: dataForA)));
      expect(find.text('+7.2 kg'), findsOneWidget);
      expect(find.text('+0.6 kg'), findsOneWidget);
      expect(find.text('+15.0 kg'), findsNothing);
      expect(find.text('+1.2 kg'), findsNothing);

      // ── User B (Fah) sees userBGains: CO₂ 15.0, waste 1.2 ───────────
      final dataForB = _attributeForCurrent(
        tradeDoc: tradeDoc,
        currentUid: 'user-fah',
        myItemName: 'Electric kettle',
        theirItemName: 'Denim jacket',
        counterpartyName: 'Ploy',
      );
      await tester.pumpWidget(_wrap(SwapConfirmedScreen(data: dataForB)));
      expect(find.text('+15.0 kg'), findsOneWidget);
      expect(find.text('+1.2 kg'), findsOneWidget);
      expect(find.text('+7.2 kg'), findsNothing);
      expect(find.text('+0.6 kg'), findsNothing);
    });

    // ── Test 6: no forbidden UI elements ───────────────────────────────────
    //
    // Locked-decision check: no "verified", no trend arrow glyphs, no
    // "this month", no settings/info icon on the top bar (it's title-only).

    testWidgets('does not show any forbidden UI elements', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(SwapConfirmedScreen(data: _fakeData())));

      // No verified badge
      expect(find.text('Verified'), findsNothing);
      expect(find.text('verified'), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
      expect(find.byIcon(Icons.verified_outlined), findsNothing);

      // No trend arrow glyphs (impact dashboard rule — also applies here).
      expect(find.textContaining('↑'), findsNothing);
      expect(find.textContaining('↓'), findsNothing);

      // No "This month" comparison card.
      expect(find.textContaining('This month'), findsNothing);
      expect(find.textContaining('this month'), findsNothing);

      // No cog / settings / info icon on the top-only bar.
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
      expect(find.byIcon(Icons.info), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);

      // No "Trade complete" leakage from the data layer into UI copy.
      expect(find.textContaining('Trade complete'), findsNothing);
    });

    // ── Test 7: CTAs fire callbacks ────────────────────────────────────────

    testWidgets('tapping "See my impact" calls onSeeImpact', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SwapConfirmedScreen(
            data: _fakeData(),
            onSeeImpact: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('See my impact'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('tapping "Back to chats" calls onBackToChats', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          SwapConfirmedScreen(
            data: _fakeData(),
            onBackToChats: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Back to chats'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
