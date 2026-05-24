/// Widget tests for WBS 7.6 — Empty State Handling
///
/// Covers every acceptance criterion listed in the entry:
///   1. Empty feed shows [EmptyState], not a blank screen
///   2. "Widen search" button opens the proximity filter sheet
///   3. Non-empty feed does NOT show [EmptyState]
///
/// Also tests the reusable [EmptyState] widget in isolation:
///   4. Icon, headline, and description are rendered
///   5. CTA button calls onCta callback
///   6. No CTA button when ctaLabel is null
library;

import 'package:ecoswap/models/item.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/screens/discover/discover_screen.dart';
import 'package:ecoswap/widgets/empty_state.dart';
import 'package:ecoswap/widgets/proximity_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

User _makeUser({String uid = 'user-1', String displayName = 'Ploy'}) {
  return User(
    uid: uid,
    email: '$uid@example.com',
    displayName: displayName,
    photoUrl: '',
    bio: '',
    homeDistrict: const HomeDistrict(
      provinceId: '10',
      provinceNameTh: 'กรุงเทพมหานคร',
      provinceNameEn: 'Bangkok',
      districtId: '1001',
      districtNameTh: 'บางมด',
      districtNameEn: 'Bang Mod',
    ),
  );
}

Item _makeItem({String id = 'item-1', String ownerId = 'user-1'}) {
  return Item(
    id: id,
    ownerId: ownerId,
    name: 'Leather tote bag',
    category: ItemCategory.clothing,
    condition: ItemCondition.likeNew,
    photoUrl: '',
    status: ItemStatus.active,
  );
}

Widget _wrap(Widget child) => MaterialApp(home: child);

/// Builds a [DiscoverScreen] with the given candidate list.
Widget _buildDiscoverScreen({
  List<User> candidates = const [],
  Map<String, List<Item>> itemsByUser = const {},
  ValueChanged<ProximityBucket>? onProximityChanged,
  ProximityBucket bucket = ProximityBucket.sameProvince,
}) {
  return _wrap(
    DiscoverScreen(
      candidates: candidates,
      itemsByUser: itemsByUser,
      proximityBucket: bucket,
      onProximityChanged: onProximityChanged,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — EmptyState widget in isolation
// ---------------------------------------------------------------------------

void main() {
  group('EmptyState widget — isolation', () {
    testWidgets('renders icon, headline, and description', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icon(Icons.explore_outlined),
            headline: 'No one nearby yet',
            description:
                'Try widening your proximity filter, or check back later — '
                'new swappers join every day.',
          ),
        ),
      );

      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.text('No one nearby yet'), findsOneWidget);
      expect(
        find.textContaining('Try widening your proximity filter'),
        findsOneWidget,
      );
    });

    testWidgets('renders CTA button when ctaLabel is provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: const Icon(Icons.explore_outlined),
            headline: 'No one nearby yet',
            description: 'Try widening your proximity filter.',
            ctaLabel: 'Widen search',
            onCta: () {},
          ),
        ),
      );

      expect(find.text('Widen search'), findsOneWidget);
      expect(find.byKey(const Key('empty_state_cta')), findsOneWidget);
    });

    testWidgets('does not render CTA button when ctaLabel is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icon(Icons.explore_outlined),
            headline: 'Your impact starts soon',
            description: 'After your first swap you will see your impact.',
          ),
        ),
      );

      expect(find.byKey(const Key('empty_state_cta')), findsNothing);
    });

    testWidgets('CTA button calls onCta callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          EmptyState(
            icon: const Icon(Icons.explore_outlined),
            headline: 'No one nearby yet',
            description: 'Try widening your proximity filter.',
            ctaLabel: 'Widen search',
            onCta: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('empty_state_cta')));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Tests — empty state on DiscoverScreen (WBS 7.6 acceptance criteria)
  // ---------------------------------------------------------------------------

  group('DiscoverScreen — WBS 7.6 empty state', () {
    // AC 1: Empty feed shows empty state, not a blank screen.
    testWidgets(
      'empty candidates list shows EmptyState with correct copy, not a blank screen',
      (tester) async {
        await tester.pumpWidget(
          _buildDiscoverScreen(candidates: [], itemsByUser: {}),
        );
        await tester.pumpAndSettle();

        // EmptyState widget is present.
        expect(find.byType(EmptyState), findsOneWidget);

        // Exact copy from Style Guide §10.
        expect(find.text('No one nearby yet'), findsOneWidget);
        expect(
          find.textContaining('Try widening your proximity filter'),
          findsOneWidget,
        );
        expect(find.text('Widen search'), findsOneWidget);

        // No swipe card shown.
        expect(find.byType(SwipeCard), findsNothing);
      },
    );

    // AC 2: "Widen search" button opens the proximity filter sheet.
    testWidgets(
      '"Widen search" button opens the proximity filter sheet',
      (tester) async {
        await tester.pumpWidget(
          _buildDiscoverScreen(candidates: [], itemsByUser: {}),
        );
        await tester.pumpAndSettle();

        // The button must be visible.
        expect(find.text('Widen search'), findsOneWidget);

        // Tap the CTA button.
        await tester.tap(find.text('Widen search'));
        await tester.pumpAndSettle();

        // The [ProximityFilterSheet] must have appeared.
        expect(find.byType(ProximityFilterSheet), findsOneWidget);
      },
    );

    // AC 3: Non-empty feed does NOT show empty state.
    testWidgets('non-empty candidates list does not show EmptyState', (
      tester,
    ) async {
      final user = _makeUser();
      final item = _makeItem(ownerId: user.uid);

      await tester.pumpWidget(
        _buildDiscoverScreen(
          candidates: [user],
          itemsByUser: {
            user.uid: [item],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('No one nearby yet'), findsNothing);
      expect(find.byType(SwipeCard), findsOneWidget);
    });
  });
}
