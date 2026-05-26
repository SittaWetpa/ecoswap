/// Widget tests for MainShell (navigation shell / bottom nav).
///
/// All four tab screens are replaced with lightweight stub widgets via
/// [MainShell.tabOverrides] so the tests never touch Firebase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/screens/shell/main_shell.dart';

// ---------------------------------------------------------------------------
// Stub screens injected via tabOverrides
// ---------------------------------------------------------------------------

class _StubDiscover extends StatelessWidget {
  const _StubDiscover();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Stub Discover')));
}

class _StubChats extends StatelessWidget {
  const _StubChats();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Stub Chats')));
}

class _StubImpact extends StatelessWidget {
  const _StubImpact();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Impact dashboard coming soon')));
}

class _StubProfile extends StatelessWidget {
  const _StubProfile();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Stub Profile')));
}

// ---------------------------------------------------------------------------
// Helper — builds MainShell with all four tabs overridden
// ---------------------------------------------------------------------------

Widget _buildShell() {
  return MaterialApp(
    home: MainShell(
      tabOverrides: const {
        0: _StubDiscover(),
        1: _StubChats(),
        2: _StubImpact(),
        3: _StubProfile(),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MainShell', () {
    testWidgets(
      'tab_switching — starts on Discover (index 0); tapping Chats shows Chats content',
      (tester) async {
        await tester.pumpWidget(_buildShell());
        await tester.pump();

        // Index 0 is active by default — Discover stub is visible.
        expect(find.text('Stub Discover'), findsOneWidget);

        // Tap the "Chats" label in the bottom nav.
        await tester.tap(find.text('Chats'));
        await tester.pump();

        // After switching, Chats stub content is visible.
        expect(find.text('Stub Chats'), findsOneWidget);
      },
    );

    testWidgets('profile_tab — tapping Profile tab renders Profile content', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell());
      await tester.pump();

      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(find.text('Stub Profile'), findsOneWidget);
    });

    testWidgets('impact_tab — tapping Impact tab shows placeholder text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell());
      await tester.pump();

      await tester.tap(find.text('Impact'));
      await tester.pump();

      expect(find.text('Impact dashboard coming soon'), findsOneWidget);
    });

    testWidgets('bottom_nav_visible — bottom nav container found by key', (
      tester,
    ) async {
      await tester.pumpWidget(_buildShell());
      await tester.pump();

      expect(find.byKey(const Key('bottomNav')), findsOneWidget);
    });
  });
}
