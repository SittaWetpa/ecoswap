import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class InvalidEmailException implements Exception {
  final String message;
  const InvalidEmailException(this.message);
}

class WeakPasswordException implements Exception {
  final String message;
  const WeakPasswordException(this.message);
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class WrongPasswordException implements Exception {
  final String message;
  const WrongPasswordException(this.message);
}

/// Typedef for the Firestore user-doc write so tests can inject a simple
/// closure instead of trying to fake the sealed FirebaseFirestore hierarchy.
typedef UserDocWriter =
    Future<void> Function(String uid, Map<String, dynamic> data);

/// Returns the default writer that writes to the real Firestore instance.
UserDocWriter _defaultWriter() {
  return (String uid, Map<String, dynamic> data) =>
      FirebaseFirestore.instance.collection('users').doc(uid).set(data);
}

class AuthService {
  final firebase_auth.FirebaseAuth _auth;
  final UserDocWriter _writeUserDoc;

  AuthService({firebase_auth.FirebaseAuth? auth, UserDocWriter? userDocWriter})
    : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
      _writeUserDoc = userDocWriter ?? _defaultWriter();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<firebase_auth.User> signUp(String email, String password) async {
    // Client-side validation before calling Firebase
    if (!_emailRegex.hasMatch(email)) {
      throw const InvalidEmailException('Please enter a valid email address.');
    }
    if (password.length < 8) {
      throw const WeakPasswordException(
        'Password must be at least 8 characters.',
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;

      // Write /users/{uid} stub document
      await _writeUserDoc(user.uid, {
        'email': email,
        'displayName': '',
        'photoUrl': '',
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
        'homeDistrict': {
          'provinceId': '',
          'provinceNameTh': '',
          'provinceNameEn': '',
          'districtId': '',
          'districtNameTh': '',
          'districtNameEn': '',
        },
        'tradesCount': 0,
        'totalCo2Saved': 0,
        'totalWasteDiverted': 0,
      });

      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw const AuthException(
            'An account with this email already exists.',
          );
        case 'network-request-failed':
          throw const AuthException(
            'Network error. Please check your connection.',
          );
        default:
          throw const AuthException('Something went wrong. Please try again.');
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<firebase_auth.User> signIn(String email, String password) async {
    // Client-side validation before calling Firebase
    if (!_emailRegex.hasMatch(email)) {
      throw const InvalidEmailException('Please enter a valid email address.');
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!;
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw const WrongPasswordException(
            'Incorrect password. Please try again.',
          );
        case 'user-not-found':
          throw const AuthException('No account found with this email.');
        case 'network-request-failed':
          throw const AuthException(
            'Network error. Please check your connection.',
          );
        default:
          throw const AuthException('Something went wrong. Please try again.');
      }
    }
  }
}
