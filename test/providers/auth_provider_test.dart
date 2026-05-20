import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecoswap/providers/auth_provider.dart' as auth_prov;

// ---------------------------------------------------------------------------
// Fake Firebase Auth — emits events from a controller we control in tests.
// ---------------------------------------------------------------------------

class _FakeUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'test-uid';
}

class _FakeFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  final StreamController<firebase_auth.User?> _controller =
      StreamController<firebase_auth.User?>.broadcast();

  firebase_auth.User? _currentUser;

  /// Simulate a sign-in event.
  void emitSignIn(firebase_auth.User user) {
    _currentUser = user;
    _controller.add(user);
  }

  /// Simulate a sign-out event.
  void emitSignOut() {
    _currentUser = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }

  @override
  firebase_auth.User? get currentUser => _currentUser;

  @override
  Stream<firebase_auth.User?> authStateChanges() => _controller.stream;
}

// ---------------------------------------------------------------------------
// Helper widget: shows "signed-in" or "signed-out" by reading AuthProvider.
// ---------------------------------------------------------------------------

class _AuthConsumerWidget extends StatelessWidget {
  const _AuthConsumerWidget();

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<auth_prov.AuthProvider>().currentUser;
    return Text(user != null ? 'signed-in' : 'signed-out');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthProvider', () {
    late _FakeFirebaseAuth fakeAuth;

    setUp(() {
      fakeAuth = _FakeFirebaseAuth();
    });

    tearDown(() {
      fakeAuth.dispose();
    });

    // -------------------------------------------------------------------------
    // Test 1: provider emits new value (notifies listeners) when signOut is
    // simulated (auth stream emits null).
    // -------------------------------------------------------------------------
    test('notifies listeners with null after signOut', () async {
      final provider =
          auth_prov.AuthProvider(firebaseAuth: fakeAuth);
      addTearDown(provider.dispose);

      final emittedValues = <firebase_auth.User?>[];
      provider.addListener(() => emittedValues.add(provider.currentUser));

      // Simulate sign-in then sign-out
      fakeAuth.emitSignIn(_FakeUser());
      await Future<void>.delayed(Duration.zero); // let stream deliver
      fakeAuth.emitSignOut();
      await Future<void>.delayed(Duration.zero);

      // After sign-out the last emitted value is null
      expect(emittedValues.last, isNull);
    });

    // -------------------------------------------------------------------------
    // Test 2: widget reading the provider rebuilds when auth state changes.
    // -------------------------------------------------------------------------
    testWidgets(
        'a widget reading the provider rebuilds when auth state changes',
        (tester) async {
      final provider =
          auth_prov.AuthProvider(firebaseAuth: fakeAuth);

      await tester.pumpWidget(
        ChangeNotifierProvider<auth_prov.AuthProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(body: _AuthConsumerWidget()),
          ),
        ),
      );
      // Let the widget tree settle after the initial build.
      await tester.pump();

      // Initially no user — shows signed-out
      expect(find.text('signed-out'), findsOneWidget);
      expect(find.text('signed-in'), findsNothing);

      // Simulate sign-in: stream emits a user.
      // pump() twice — first pump delivers the async stream event to the
      // listener; second pump redraws the widget tree after notifyListeners().
      fakeAuth.emitSignIn(_FakeUser());
      await tester.pump(); // microtasks: stream delivers to listener
      await tester.pump(); // rebuild from notifyListeners()

      // Widget should now show signed-in
      expect(find.text('signed-in'), findsOneWidget);
      expect(find.text('signed-out'), findsNothing);

      // Simulate sign-out
      fakeAuth.emitSignOut();
      await tester.pump(); // microtasks
      await tester.pump(); // rebuild

      // Widget reverts to signed-out
      expect(find.text('signed-out'), findsOneWidget);
      expect(find.text('signed-in'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Test 3: currentUser sync getter returns null before any auth event.
    // -------------------------------------------------------------------------
    test('currentUser returns null when no user is signed in', () {
      final provider =
          auth_prov.AuthProvider(firebaseAuth: fakeAuth);
      addTearDown(provider.dispose);
      expect(provider.currentUser, isNull);
    });

    // -------------------------------------------------------------------------
    // Test 4: currentUser sync getter reflects the signed-in user.
    // -------------------------------------------------------------------------
    test('currentUser reflects signed-in user after auth state change',
        () async {
      final provider =
          auth_prov.AuthProvider(firebaseAuth: fakeAuth);
      addTearDown(provider.dispose);

      fakeAuth.emitSignIn(_FakeUser());
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser, isNotNull);
      expect(provider.currentUser!.uid, equals('test-uid'));
    });
  });
}
