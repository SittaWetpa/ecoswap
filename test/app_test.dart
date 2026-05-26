import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecoswap/app.dart';
import 'package:ecoswap/providers/auth_provider.dart' as auth_prov;
import 'package:ecoswap/screens/shell/main_shell.dart';

class _FakeUser extends Fake implements User {}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

// Lightweight stub screens injected into MainShell so Firebase is never called.
class _StubScreen extends StatelessWidget {
  const _StubScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('stub')));
}

void main() {
  group('EcoSwapApp route guard', () {
    testWidgets('shows MainShell when authStateStream emits a non-null User', (
      tester,
    ) async {
      // Pass authProvider so screens inside MainShell can read it via
      // context.read.
      final provider = auth_prov.AuthProvider(
        firebaseAuth: _FakeFirebaseAuth(),
      );

      // Inject stub tabs so none of the real screens touch Firebase.
      const stubTabs = <int, Widget>{
        0: _StubScreen(),
        1: _StubScreen(),
        2: _StubScreen(),
        3: _StubScreen(),
      };

      await tester.pumpWidget(
        EcoSwapApp(
          authStateStream: Stream.value(_FakeUser()),
          authProvider: provider,
          authenticatedHome: const MainShell(tabOverrides: stubTabs),
        ),
      );
      // Let the StreamBuilder settle
      await tester.pump();

      // MainShell is in the widget tree — it hosts all top-level tabs.
      expect(find.byType(MainShell), findsOneWidget);
    });

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
