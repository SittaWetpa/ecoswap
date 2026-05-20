import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:ecoswap/screens/profile/profile_screen.dart';
import 'package:ecoswap/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Minimal FirebaseAuth fake — only signOut() is needed here.
// ---------------------------------------------------------------------------

class _FakeFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Stub AuthService — injects the fake FirebaseAuth and records signOut calls.
// ---------------------------------------------------------------------------

class _StubAuthService extends AuthService {
  bool signOutCalled = false;

  _StubAuthService()
      : super(
          auth: _FakeFirebaseAuth(),
          userDocWriter: (uid, data) async {},
        );

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen(_StubAuthService stub) {
  return MaterialApp(
    home: ProfileScreen(authService: stub),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProfileScreen logout', () {
    testWidgets('tapping "Log out" button shows confirmation dialog',
        (tester) async {
      final stub = _StubAuthService();
      await tester.pumpWidget(_buildScreen(stub));

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
      final stub = _StubAuthService();
      await tester.pumpWidget(_buildScreen(stub));

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
      expect(stub.signOutCalled, isFalse);
    });
  });
}
