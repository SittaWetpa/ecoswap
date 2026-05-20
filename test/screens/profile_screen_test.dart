import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecoswap/providers/auth_provider.dart' as auth_prov;
import 'package:ecoswap/screens/profile/profile_screen.dart';

// ---------------------------------------------------------------------------
// Fake FirebaseAuth — sign-out is recorded; authStateChanges returns a stream
// that stays silent so the provider never tries to talk to Firebase.
// ---------------------------------------------------------------------------

class _FakeFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  bool signOutCalled = false;

  final StreamController<firebase_auth.User?> _controller =
      StreamController<firebase_auth.User?>.broadcast();

  @override
  firebase_auth.User? get currentUser => null;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _controller.stream;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Helper — wraps ProfileScreen in a ChangeNotifierProvider<AuthProvider> so
// the screen can call context.read<AuthProvider>() without crashing.
// ---------------------------------------------------------------------------

Widget _buildScreen(auth_prov.AuthProvider provider) {
  return ChangeNotifierProvider<auth_prov.AuthProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: ProfileScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProfileScreen logout', () {
    late _FakeFirebaseAuth fakeAuth;
    late auth_prov.AuthProvider provider;

    setUp(() {
      fakeAuth = _FakeFirebaseAuth();
      provider = auth_prov.AuthProvider(firebaseAuth: fakeAuth);
    });

    tearDown(() {
      fakeAuth.dispose();
    });

    testWidgets('tapping "Log out" button shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(_buildScreen(provider));

      // The button is present on screen
      expect(find.text('Log out'), findsOneWidget);

      // Tap the button
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      // Confirmation dialog title appears
      expect(find.text('Log out?'), findsOneWidget);
    });

    testWidgets('tapping "Cancel" dismisses dialog and does NOT call signOut',
        (tester) async {
      await tester.pumpWidget(_buildScreen(provider));

      // Open dialog
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog is gone
      expect(find.text('Log out?'), findsNothing);

      // signOut was NOT called
      expect(fakeAuth.signOutCalled, isFalse);
    });

    testWidgets('tapping "Log out" in dialog calls AuthProvider.signOut',
        (tester) async {
      await tester.pumpWidget(_buildScreen(provider));

      // Open dialog
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      // There are now two "Log out" texts: the button and the dialog action.
      // Use the one inside the dialog (last finder hit).
      await tester.tap(find.text('Log out').last);
      await tester.pumpAndSettle();

      // signOut was called on the underlying FirebaseAuth fake
      expect(fakeAuth.signOutCalled, isTrue);
    });
  });
}
