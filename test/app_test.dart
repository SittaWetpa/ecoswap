import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecoswap/app.dart';

class _FakeUser extends Fake implements User {}

void main() {
  group('EcoSwapApp route guard', () {
    testWidgets(
      'shows ProfileScreen when authStateStream emits a non-null User',
      (tester) async {
        await tester.pumpWidget(
          EcoSwapApp(authStateStream: Stream.value(_FakeUser())),
        );
        // Let the StreamBuilder settle
        await tester.pump();

        // ProfileScreen is shown — the placeholder body text is visible
        expect(find.text('Profile — coming soon'), findsOneWidget);
      },
    );

    testWidgets('shows LoginScreen when authStateStream emits null', (
      tester,
    ) async {
      await tester.pumpWidget(EcoSwapApp(authStateStream: Stream.value(null)));
      await tester.pump();

      // LoginScreen renders 'Welcome back' title
      expect(find.text('Welcome back'), findsOneWidget);
      // and the Sign in button
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('shows loading indicator while stream is in waiting state', (
      tester,
    ) async {
      // A StreamController that never emits puts the StreamBuilder into
      // ConnectionState.waiting until we pump.
      final controller = StreamController<User?>();
      addTearDown(controller.close);

      await tester.pumpWidget(EcoSwapApp(authStateStream: controller.stream));
      // Do NOT pump — stay in waiting state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
