import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecoswap/app.dart';
import 'package:ecoswap/providers/auth_provider.dart' as auth_prov;
import 'package:ecoswap/screens/profile/profile_screen.dart';

class _FakeUser extends Fake implements User {}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

void main() {
  group('EcoSwapApp route guard', () {
    testWidgets(
      'shows ProfileScreen when authStateStream emits a non-null User',
      (tester) async {
        // Pass authProvider so ProfileScreen can read it via context.read.
        final provider = auth_prov.AuthProvider(
          firebaseAuth: _FakeFirebaseAuth(),
        );

        await tester.pumpWidget(
          EcoSwapApp(
            authStateStream: Stream.value(_FakeUser()),
            authProvider: provider,
          ),
        );
        // Let the StreamBuilder settle
        await tester.pump();

        // ProfileScreen is in the widget tree (WBS 5.4 replaced placeholder).
        expect(find.byType(ProfileScreen), findsOneWidget);
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
