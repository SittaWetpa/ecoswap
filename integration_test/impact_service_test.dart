/// Integration test for WBS 11.2 — Impact Aggregation via Denormalized
/// Counters.
///
/// Exercises [ImpactService.getCurrentUserImpact] against the local Firebase
/// Emulator. The WBS Testing section says:
///
///   "Integration test: complete a trade, then read impact — values reflect
///    the new trade"
///
/// The trade-completion path is owned by WBS 10.6's Cloud Function (atomic
/// transaction: write `/trades/`, flip both items, increment counters on both
/// `/users/` docs). 11.2 is the read-side service and owns no write path.
///
/// We therefore simulate the 10.6 transaction by writing the same counter
/// shape directly to `/users/{uid}` in the emulator — this verifies that the
/// read shape produced by 11.2 matches what the writer produces, against a
/// real Firestore instance. When 10.6 lands, a follow-up test can call the
/// Cloud Function end-to-end; the contract verified here (the read mapping)
/// will not change.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ecoswap/services/impact_service.dart';

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
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  });

  testWidgets(
    'reading impact after a simulated trade write reflects the new counters',
    (tester) async {
      const uid = 'integration-impact-uid';
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);

      // 1. Initial state — fresh user with all counters at 0, matching the
      //    document AuthService.signUp writes in WBS 4.1.
      await userDoc.set({
        'email': 'impact-tester@example.com',
        'displayName': '',
        'photoUrl': '',
        'bio': '',
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
        'createdAt': FieldValue.serverTimestamp(),
      });

      final service = ImpactService(
        userDocReader: (u) async {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(u)
              .get();
          return snap.exists ? snap.data() : null;
        },
        currentUidProvider: () => uid,
      );

      final before = await service.getCurrentUserImpact();
      expect(before, equals(UserImpact.zero));

      // 2. Simulate the WBS 10.6 transaction's user-counter increment for one
      //    completed trade. The values mirror the worked example in WBS 11.1
      //    for the receiving side of a clothing ⇄ kitchenware swap.
      await userDoc.update({
        'tradesCount': FieldValue.increment(1),
        'totalCo2Saved': FieldValue.increment(7.2),
        'totalWasteDiverted': FieldValue.increment(0.6),
      });

      // 3. Read via ImpactService — values must reflect the new trade.
      final after = await service.getCurrentUserImpact();

      expect(after.trades, equals(1));
      expect(after.co2Kg, closeTo(7.2, 1e-9));
      expect(after.wasteKg, closeTo(0.6, 1e-9));
    },
  );
}
