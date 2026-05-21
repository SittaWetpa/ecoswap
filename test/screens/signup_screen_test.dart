import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:ecoswap/screens/auth/signup_screen.dart';
import 'package:ecoswap/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Minimal FirebaseAuth fake — only used to satisfy AuthService constructor
// (signUp() is overridden so createUserWithEmailAndPassword never runs).
// ---------------------------------------------------------------------------

class _StubFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {}

// ---------------------------------------------------------------------------
// Fake AuthService that throws a configurable exception on signUp()
// ---------------------------------------------------------------------------

class _FakeAuthService extends AuthService {
  final Exception _toThrow;

  _FakeAuthService(this._toThrow)
    : super(auth: _StubFirebaseAuth(), userDocWriter: (_, _) async {});

  @override
  Future<firebase_auth.User> signUp(String email, String password) async {
    throw _toThrow;
  }
}

// ---------------------------------------------------------------------------
// Widget tests
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
  routes: {
    '/profile-setup': (_) => const Scaffold(body: Text('profile-setup')),
  },
  home: child,
);

void main() {
  group('SignupScreen widget', () {
    testWidgets('shows error text when AuthService throws AuthException '
        '(email-already-in-use)', (WidgetTester tester) async {
      final fakeService = _FakeAuthService(
        const AuthException('An account with this email already exists.'),
      );

      await tester.pumpWidget(_wrap(SignupScreen(authService: fakeService)));

      // Fill in fields
      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      // Tap the button
      await tester.tap(find.text('Create account'));
      await tester.pump(); // start async
      await tester.pump(); // settle

      // Error text must appear on screen
      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error text for InvalidEmailException', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeAuthService(
        const InvalidEmailException('Please enter a valid email address.'),
      );

      await tester.pumpWidget(_wrap(SignupScreen(authService: fakeService)));

      await tester.enterText(find.byType(TextField).at(0), 'bad-email');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows error text for WeakPasswordException', (
      WidgetTester tester,
    ) async {
      final fakeService = _FakeAuthService(
        const WeakPasswordException('Password must be at least 8 characters.'),
      );

      await tester.pumpWidget(_wrap(SignupScreen(authService: fakeService)));

      await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );
    });

    testWidgets('renders title, subtitle, and Create account button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SignupScreen(
            authService: _FakeAuthService(const AuthException('err')),
          ),
        ),
      );

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Start swapping with people near you.'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      // The bottom toggle is a RichText with two spans.
      // Verify it is present by finding the RichText widget whose
      // plain text contains both parts.
      expect(
        find.byWidgetPredicate((w) {
          if (w is RichText) {
            final plain = w.text.toPlainText();
            return plain.contains('Already have an account?') &&
                plain.contains('Sign in');
          }
          return false;
        }),
        findsOneWidget,
      );
    });
  });
}
