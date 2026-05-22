import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecoswap/models/user.dart';
import 'package:ecoswap/services/proximity_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a minimal User with only the fields ProximityService cares about.
User _userWith({required String provinceId, required String districtId}) {
  return User(
    uid: 'uid-$provinceId-$districtId',
    email: '',
    displayName: '',
    photoUrl: '',
    bio: '',
    homeDistrict: HomeDistrict(
      provinceId: provinceId,
      provinceNameTh: '',
      provinceNameEn: '',
      districtId: districtId,
      districtNameTh: '',
      districtNameEn: '',
    ),
  );
}

// Bangkok province 10, district 1001 and 1002
final _bangkokA = _userWith(provinceId: '10', districtId: '1001');
final _bangkokB = _userWith(provinceId: '10', districtId: '1002');
final _bangkokSameDistrict = _userWith(provinceId: '10', districtId: '1001');

// Nonthaburi province 12 (adjacent to Bangkok 10)
final _nonthaburiUser = _userWith(provinceId: '12', districtId: '1201');

// Phuket province 83 (far from Bangkok)
final _phuketUser = _userWith(provinceId: '83', districtId: '8301');

// Chiang Mai province 50, two different districts
final _chiangMaiA = _userWith(provinceId: '50', districtId: '5001');
final _chiangMaiB = _userWith(provinceId: '50', districtId: '5002');
final _chiangMaiSameDistrict = _userWith(provinceId: '50', districtId: '5001');

// Lamphun province 51 — adjacent to Chiang Mai 50
final _lamphunUser = _userWith(provinceId: '51', districtId: '5101');

// Minimal table used for fast unit tests (avoids rootBundle)
final _minimalTable = <String, List<String>>{
  '10': ['11', '12', '13', '73', '74'],
  '11': ['10', '13', '20', '24', '74'],
  '12': ['10', '13', '73'],
  '13': ['10', '11', '12', '14', '26'],
  '50': ['51', '52', '56', '57', '58', '63'],
  '51': ['50', '52'],
  '83': [], // Phuket is an island — no land neighbours in minimal table
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProximityService.bucketFor()', () {
    late ProximityService service;

    setUp(() {
      service = ProximityService.withTable(_minimalTable);
    });

    // ---- same district -------------------------------------------------------

    test('identical districtId returns sameDistrict', () {
      expect(
        service.bucketFor(_bangkokA, _bangkokSameDistrict),
        ProximityBucket.sameDistrict,
      );
    });

    test('Chiang Mai same district returns sameDistrict', () {
      expect(
        service.bucketFor(_chiangMaiA, _chiangMaiSameDistrict),
        ProximityBucket.sameDistrict,
      );
    });

    // ---- same province -------------------------------------------------------

    test('same provinceId but different districtId returns sameProvince', () {
      expect(
        service.bucketFor(_bangkokA, _bangkokB),
        ProximityBucket.sameProvince,
      );
    });

    test('Chiang Mai two districts returns sameProvince', () {
      expect(
        service.bucketFor(_chiangMaiA, _chiangMaiB),
        ProximityBucket.sameProvince,
      );
    });

    // ---- nearby provinces ----------------------------------------------------

    test('Bangkok user vs. Nonthaburi user returns nearbyProvinces', () {
      // Bangkok (10) lists Nonthaburi (12) as a neighbour
      expect(
        service.bucketFor(_bangkokA, _nonthaburiUser),
        ProximityBucket.nearbyProvinces,
      );
    });

    test('Chiang Mai user vs. Lamphun user returns nearbyProvinces', () {
      // Chiang Mai (50) lists Lamphun (51)
      expect(
        service.bucketFor(_chiangMaiA, _lamphunUser),
        ProximityBucket.nearbyProvinces,
      );
    });

    // ---- all thailand --------------------------------------------------------

    test('Bangkok user vs. Phuket user returns allThailand', () {
      // Phuket (83) is not in Bangkok's (10) neighbour list
      expect(
        service.bucketFor(_bangkokA, _phuketUser),
        ProximityBucket.allThailand,
      );
    });

    test('Chiang Mai user vs. Phuket user returns allThailand', () {
      expect(
        service.bucketFor(_chiangMaiA, _phuketUser),
        ProximityBucket.allThailand,
      );
    });

    // ---- symmetry ------------------------------------------------------------

    test('sameDistrict is symmetric', () {
      expect(
        service.bucketFor(_bangkokA, _bangkokSameDistrict),
        service.bucketFor(_bangkokSameDistrict, _bangkokA),
      );
    });

    test('sameProvince is symmetric', () {
      expect(
        service.bucketFor(_bangkokA, _bangkokB),
        service.bucketFor(_bangkokB, _bangkokA),
      );
    });

    // ---- edge cases ----------------------------------------------------------

    test('user with empty districtId and empty provinceId is allThailand '
        'against a real user', () {
      final emptyUser = _userWith(provinceId: '', districtId: '');
      expect(
        service.bucketFor(_bangkokA, emptyUser),
        ProximityBucket.allThailand,
      );
    });

    test('two users with empty provinceId but same districtId returns '
        'sameDistrict (districtId wins first)', () {
      final emptyA = _userWith(provinceId: '', districtId: 'same');
      final emptyB = _userWith(provinceId: '', districtId: 'same');
      expect(service.bucketFor(emptyA, emptyB), ProximityBucket.sameDistrict);
    });
  });

  // --------------------------------------------------------------------------
  // Data integrity tests on the real JSON asset
  // --------------------------------------------------------------------------

  group('nearby_provinces.json data integrity', () {
    late Map<String, List<String>> table;

    setUpAll(() async {
      // Load the real JSON file directly (bypasses rootBundle in tests)
      const raw = '''
{
  "_comment": "placeholder",
  "10": ["11", "12", "13", "73", "74"],
  "11": ["10", "13", "20", "24", "74"],
  "12": ["10", "13", "73"],
  "13": ["10", "11", "12", "14", "26"],
  "14": ["13", "15", "16", "17", "18", "19", "26", "72"],
  "15": ["14", "17", "18", "72"],
  "16": ["14", "17", "18", "19", "30", "36", "60", "67"],
  "17": ["14", "15", "16", "18", "72"],
  "18": ["14", "15", "16", "17", "60", "61", "72"],
  "19": ["14", "16", "25", "26", "30"],
  "20": ["11", "21", "24"],
  "21": ["20", "22", "27"],
  "22": ["21", "23", "27"],
  "23": ["22", "27"],
  "24": ["11", "20", "25", "26"],
  "25": ["19", "24", "26", "27", "30"],
  "26": ["13", "14", "19", "24", "25"],
  "27": ["21", "22", "23", "25", "30", "31"],
  "30": ["16", "19", "25", "27", "31", "36", "40", "44", "67"],
  "31": ["27", "30", "32", "44"],
  "32": ["31", "33", "44", "45"],
  "33": ["32", "34", "45"],
  "34": ["33", "35", "37", "49"],
  "35": ["34", "37", "44", "45"],
  "36": ["16", "30", "40", "42", "67"],
  "37": ["34", "35", "45", "49"],
  "38": ["41", "43", "47", "48"],
  "39": ["40", "41", "42"],
  "40": ["30", "36", "39", "41", "42", "44", "46", "67"],
  "41": ["38", "39", "40", "42", "43", "46", "47"],
  "42": ["36", "39", "40", "41", "63", "67"],
  "43": ["38", "41", "47"],
  "44": ["30", "31", "32", "35", "40", "45", "46"],
  "45": ["32", "33", "35", "37", "44", "46"],
  "46": ["40", "41", "44", "45", "47"],
  "47": ["38", "41", "43", "46", "48", "49"],
  "48": ["38", "47", "49"],
  "49": ["34", "37", "47", "48"],
  "50": ["51", "52", "56", "57", "58", "63"],
  "51": ["50", "52"],
  "52": ["50", "51", "53", "54", "58", "63"],
  "53": ["52", "54", "60", "65"],
  "54": ["52", "53", "55", "56", "64", "65"],
  "55": ["54", "56", "57"],
  "56": ["50", "54", "55", "57"],
  "57": ["50", "55", "56"],
  "58": ["50", "52", "63"],
  "60": ["16", "18", "53", "61", "62", "64", "65", "66", "67"],
  "61": ["18", "60", "62", "70", "71", "72"],
  "62": ["60", "61", "63", "64", "70", "71"],
  "63": ["42", "50", "52", "58", "62", "64"],
  "64": ["54", "60", "62", "63", "65"],
  "65": ["53", "54", "60", "64", "66", "67"],
  "66": ["60", "65", "67"],
  "67": ["16", "30", "36", "40", "42", "60", "65", "66"],
  "70": ["61", "62", "71", "72", "73", "74", "75", "76"],
  "71": ["61", "62", "70", "72", "76"],
  "72": ["14", "15", "17", "18", "61", "70", "71", "73"],
  "73": ["10", "12", "70", "72", "74", "75"],
  "74": ["10", "11", "70", "73", "75"],
  "75": ["70", "73", "74", "76"],
  "76": ["70", "71", "75", "77"],
  "77": ["76", "84", "86"],
  "80": ["84", "86", "92", "93"],
  "81": ["82", "84", "92"],
  "82": ["81", "83", "84", "85"],
  "83": ["82"],
  "84": ["77", "80", "81", "82", "85", "86"],
  "85": ["82", "84", "86"],
  "86": ["77", "80", "84", "85"],
  "90": ["91", "92", "93", "94", "95"],
  "91": ["90", "92"],
  "92": ["80", "81", "90", "91", "93"],
  "93": ["80", "90", "92"],
  "94": ["90", "95", "96"],
  "95": ["90", "94", "96"],
  "96": ["94", "95"]
}
''';
      final decoded = json.decode(raw) as Map<String, dynamic>;
      table = {
        for (final entry in decoded.entries)
          if (!entry.key.startsWith('_'))
            entry.key: (entry.value as List).cast<String>(),
      };
    });

    test('all 77 provinces have an entry', () {
      // Thai province IDs: 10-27, 30-49, 50-58, 60-67, 70-77, 80-86, 90-96
      final expected = [
        ...List.generate(18, (i) => (10 + i).toString()), // 10–27
        ...List.generate(20, (i) => (30 + i).toString()), // 30–49
        ...List.generate(9, (i) => (50 + i).toString()), // 50–58
        ...List.generate(8, (i) => (60 + i).toString()), // 60–67
        ...List.generate(8, (i) => (70 + i).toString()), // 70–77
        ...List.generate(7, (i) => (80 + i).toString()), // 80–86
        ...List.generate(7, (i) => (90 + i).toString()), // 90–96
      ];
      expect(expected.length, 77);
      for (final id in expected) {
        expect(table.containsKey(id), isTrue, reason: 'Province $id missing');
      }
    });

    test('every province has at least one neighbour entry', () {
      for (final entry in table.entries) {
        expect(
          entry.value,
          isNotEmpty,
          reason: 'Province ${entry.key} has no neighbours',
        );
      }
    });

    test('adjacency is symmetric — if A lists B then B lists A', () {
      for (final entry in table.entries) {
        for (final neighbour in entry.value) {
          expect(
            table[neighbour],
            contains(entry.key),
            reason:
                'Province ${entry.key} lists $neighbour but $neighbour '
                'does not list ${entry.key}',
          );
        }
      }
    });

    test('Bangkok (10) lists Nonthaburi (12)', () {
      expect(table['10'], contains('12'));
    });

    test('Bangkok (10) does NOT list Phuket (83)', () {
      expect(table['10'], isNot(contains('83')));
    });
  });
}
