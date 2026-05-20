import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// App-wide auth state provider.
///
/// Wraps [FirebaseAuth.authStateChanges] so that every widget that needs
/// the current user reads this provider instead of reaching into
/// [FirebaseAuth.instance] directly.
///
/// - [currentUser] — synchronous getter; null when signed out.
/// - [authStateChanges] — stream of [User?] for widgets that need to react
///   to sign-in / sign-out transitions.
///
/// The [firebaseAuth] constructor parameter is injectable so tests can
/// supply a fake without spinning up a real Firebase project.
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth;

  User? _currentUser;

  AuthProvider({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance {
    // Initialise synchronously from the current session (handles cold start
    // where Firebase already has a cached token).
    _currentUser = _auth.currentUser;

    // React to every future auth-state change and notify listeners so that
    // any widget tree subscribed via Consumer / context.watch rebuilds.
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  /// The currently signed-in [User], or null when signed out.
  ///
  /// This is the **only** place in the Flutter app that reads
  /// [FirebaseAuth.instance.currentUser] directly.
  User? get currentUser => _currentUser;

  /// Raw stream — use this when you need a [StreamBuilder] rather than
  /// a [Consumer].  Delegates to [FirebaseAuth.authStateChanges] so
  /// listeners receive events immediately on subscription.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
