import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ecoswap/services/swipe_service.dart';

// Emulator Firebase options — matches CI config in .github/workflows/ci.yml.
const _kTestFirebaseOptions = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: '1:000000000000:android:0000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'ecoswap-ci',
  storageBucket: 'ecoswap-ci.appspot.com',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: _kTestFirebaseOptions);
    // Point to the local Firestore emulator.
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  // WBS 8.1 Testing — Integration test: rapid successive swipes do not produce
  // duplicate documents.
  testWidgets(
    'rapid successive swipes produce distinct Firestore document IDs',
    (tester) async {
      const swiperId = 'integration-test-swiper';
      const targetA = 'target-user-a';
      const targetB = 'target-user-b';

      final service = SwipeService(currentUserId: swiperId);

      // Fire two left-swipes concurrently — simulates rapid swiping.
      final results = await Future.wait([
        service.recordSwipe(targetA, 'left'),
        service.recordSwipe(targetB, 'left'),
      ]);

      final idA = results[0];
      final idB = results[1];

      // Each call must produce a unique document ID.
      expect(idA, isNotEmpty);
      expect(idB, isNotEmpty);
      expect(idA, isNot(equals(idB)));

      // Both documents must actually exist in Firestore.
      final swipes = FirebaseFirestore.instance.collection('swipes');
      final docA = await swipes.doc(idA).get();
      final docB = await swipes.doc(idB).get();

      expect(docA.exists, isTrue);
      expect(docB.exists, isTrue);
      expect(docA.data()!['targetUserId'], equals(targetA));
      expect(docB.data()!['targetUserId'], equals(targetB));
    },
  );
}
