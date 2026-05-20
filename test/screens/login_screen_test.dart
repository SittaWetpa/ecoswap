import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:ecoswap/screens/auth/login_screen.dart';
import 'package:ecoswap/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Stub AuthService that can be configured to throw on signIn
// ---------------------------------------------------------------------------

class _StubAuthService extends AuthService {
  final Exception? _errorToThrow;

  _StubAuthService({Exception? errorToThrow})
      : _errorToThrow = errorToThrow,
        super(
          auth: _NoOpFirebaseAuth(),
          userDocWriter: (uid, data) async {},
        );

  @override
  Future<firebase_auth.User> signIn(String email, String password) async {
    final err = _errorToThrow;
    if (err != null) throw err;
    return _FakeUser();
  }
}

class _NoOpFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {}

class _FakeUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'stub-uid';
}

// ---------------------------------------------------------------------------
// Widget tests
// ---------------------------------------------------------------------------

void main() {
  group('LoginScreen', () {
    testWidgets('renders title and subtitle correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: _StubAuthService()),
        ),
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to keep swapping.'), findsOneWidget);
    });

    testWidgets('renders Sign in button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: _StubAuthService()),
        ),
      );

      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets(
        'shows WrongPasswordException message as friendly error text',
        (tester) async {
      final service = _StubAuthService(
        errorToThrow: const WrongPasswordException(
            'Incorrect password. Please try again.'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: service),
        ),
      );

      // Fill in fields
      await tester.enterText(
          find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'wrongpass');

      // Tap sign in
      await tester.tap(find.text('Sign in'));
      await tester.pump(); // start async
      await tester.pump(); // settle

      expect(
        find.text('Incorrect password. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'shows InvalidEmailException message as friendly error text',
        (tester) async {
      final service = _StubAuthService(
        errorToThrow: const InvalidEmailException(
            'Please enter a valid email address.'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: service),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'bad-email');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Please enter a valid email address.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'shows AuthException message as friendly error text', (tester) async {
      final service = _StubAuthService(
        errorToThrow: const AuthException('No account found with this email.'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: service),
        ),
      );

      await tester.enterText(
          find.byType(TextField).first, 'missing@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('No account found with this email.'),
        findsOneWidget,
      );
    });

    testWidgets('Forgot password? link is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: _StubAuthService()),
        ),
      );

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('bottom toggle shows New here? and Create an account',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(authService: _StubAuthService()),
        ),
      );

      // The bottom toggle uses RichText with TextSpan children, so
      // find.textContaining won't reach the spans. Use byWidgetPredicate
      // to inspect the flattened plain text of the RichText.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('New here?'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Create an account'),
        ),
        findsOneWidget,
      );
    });
  });
}
