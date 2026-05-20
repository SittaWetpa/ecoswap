import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:ecoswap/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Manual mocks — avoid faking sealed Firestore classes entirely.
// FirebaseAuth is not sealed so Fake is fine there.
// ---------------------------------------------------------------------------

class _MockUser extends Fake implements firebase_auth.User {
  @override
  String get uid => 'test-uid-123';

  @override
  String? get email => 'test@example.com';
}

class _MockUserCredential extends Fake
    implements firebase_auth.UserCredential {
  @override
  firebase_auth.User? get user => _MockUser();
}

class _MockFirebaseAuth extends Fake implements firebase_auth.FirebaseAuth {
  bool createUserCalled = false;
  firebase_auth.FirebaseAuthException? errorToThrow;

  @override
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createUserCalled = true;
    if (errorToThrow != null) throw errorToThrow!;
    return _MockUserCredential();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AuthService.signUp()', () {
    late _MockFirebaseAuth mockAuth;
    late String? capturedUid;
    late Map<String, dynamic>? capturedData;

    /// Builds a service that captures the Firestore write in local variables.
    AuthService makeService() {
      capturedUid = null;
      capturedData = null;
      return AuthService(
        auth: mockAuth,
        userDocWriter: (uid, data) async {
          capturedUid = uid;
          capturedData = data;
        },
      );
    }

    setUp(() {
      mockAuth = _MockFirebaseAuth();
    });

    test(
        'valid email + 8+ char password creates user and writes Firestore doc '
        'with tradesCount=0, totalCo2Saved=0, totalWasteDiverted=0', () async {
      final service = makeService();
      final user = await service.signUp('test@example.com', 'password123');

      expect(user.uid, equals('test-uid-123'));
      expect(mockAuth.createUserCalled, isTrue);
      expect(capturedUid, equals('test-uid-123'));

      final data = capturedData!;
      expect(data['tradesCount'], equals(0));
      expect(data['totalCo2Saved'], equals(0));
      expect(data['totalWasteDiverted'], equals(0));
      expect(data['email'], equals('test@example.com'));
      expect(data['displayName'], equals(''));
      expect(data['photoUrl'], equals(''));
      expect(data['bio'], equals(''));
      // createdAt is FieldValue.serverTimestamp() — not null
      expect(data['createdAt'], isNotNull);
      // homeDistrict sub-object has all 6 string fields
      final homeDistrict = data['homeDistrict'] as Map<String, dynamic>;
      expect(homeDistrict.keys.toSet(),
          equals({'provinceId', 'provinceNameTh', 'provinceNameEn',
                  'districtId', 'districtNameTh', 'districtNameEn'}));
      for (final v in homeDistrict.values) {
        expect(v, equals(''));
      }
    });

    test(
        'invalid email format throws InvalidEmailException, '
        'does NOT call Firebase', () async {
      final service = makeService();
      await expectLater(
        () => service.signUp('not-an-email', 'password123'),
        throwsA(isA<InvalidEmailException>()),
      );
      expect(mockAuth.createUserCalled, isFalse);
      expect(capturedUid, isNull);
    });

    test(
        'password shorter than 8 chars throws WeakPasswordException, '
        'does NOT call Firebase', () async {
      final service = makeService();
      await expectLater(
        () => service.signUp('test@example.com', 'short'),
        throwsA(isA<WeakPasswordException>()),
      );
      expect(mockAuth.createUserCalled, isFalse);
      expect(capturedUid, isNull);
    });

    test('Firebase email-already-in-use maps to friendly AuthException',
        () async {
      mockAuth.errorToThrow = firebase_auth.FirebaseAuthException(
        code: 'email-already-in-use',
      );
      final service = makeService();

      await expectLater(
        () => service.signUp('test@example.com', 'password123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            equals('An account with this email already exists.'),
          ),
        ),
      );
    });

    test('Firebase network-request-failed maps to friendly AuthException',
        () async {
      mockAuth.errorToThrow = firebase_auth.FirebaseAuthException(
        code: 'network-request-failed',
      );
      final service = makeService();

      await expectLater(
        () => service.signUp('test@example.com', 'password123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            equals('Network error. Please check your connection.'),
          ),
        ),
      );
    });

    test('unknown Firebase error maps to generic AuthException', () async {
      mockAuth.errorToThrow = firebase_auth.FirebaseAuthException(
        code: 'unknown-code',
      );
      final service = makeService();

      await expectLater(
        () => service.signUp('test@example.com', 'password123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            equals('Something went wrong. Please try again.'),
          ),
        ),
      );
    });
  });
}
