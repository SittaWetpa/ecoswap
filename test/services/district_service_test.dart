import 'dart:convert';

import 'package:ecoswap/services/district_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal inline fixture — just enough entries to cover all search paths.
// We include several districts with "bang" / "บาง" in their names so the
// acceptance criteria ("at least one") are met, plus one unrelated entry.
// ---------------------------------------------------------------------------
final _fixtureDistricts = [
  // Bangkok districts with "bang" in English and "บาง" in Thai
  {
    'provinceId': '1',
    'provinceNameTh': 'กรุงเทพมหานคร',
    'provinceNameEn': 'Bangkok',
    'districtId': '1004',
    'districtNameTh': 'เขตบางรัก',
    'districtNameEn': 'Khet Bang Rak',
  },
  {
    'provinceId': '1',
    'provinceNameTh': 'กรุงเทพมหานคร',
    'provinceNameEn': 'Bangkok',
    'districtId': '1005',
    'districtNameTh': 'เขตบางเขน',
    'districtNameEn': 'Khet Bang Khen',
  },
  // An unrelated entry with no "bang"
  {
    'provinceId': '10',
    'provinceNameTh': 'กาญจนบุรี',
    'provinceNameEn': 'Kanchanaburi',
    'districtId': '1001',
    'districtNameTh': 'เมืองกาญจนบุรี',
    'districtNameEn': 'Mueang Kanchanaburi',
  },
];

String _fixtureJson() => jsonEncode(_fixtureDistricts);

DistrictService _makeService() {
  return DistrictService(assetLoader: (_) async => _fixtureJson());
}

void main() {
  group('DistrictService', () {
    test('loadAll returns all entries from fixture', () async {
      final svc = _makeService();
      final all = await svc.loadAll();
      expect(all, hasLength(_fixtureDistricts.length));
    });

    test('loadAll is cached — loader called only once', () async {
      var callCount = 0;
      final svc = DistrictService(
        assetLoader: (_) async {
          callCount++;
          return _fixtureJson();
        },
      );
      await svc.loadAll();
      await svc.loadAll();
      expect(callCount, 1);
    });

    // -----------------------------------------------------------------------
    // Acceptance criterion 1: English search
    // -----------------------------------------------------------------------
    test(
      'searchByName("bang") returns at least one district with "bang" in English name',
      () async {
        final svc = _makeService();
        final results = await svc.searchByName('bang');
        expect(results, isNotEmpty);
        expect(
          results.any((d) => d.districtNameEn.toLowerCase().contains('bang')),
          isTrue,
          reason:
              'Expected at least one district with "bang" in districtNameEn',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Acceptance criterion 2: Thai search
    // -----------------------------------------------------------------------
    test(
      'searchByName("บาง") returns at least one district with "บาง" in Thai name',
      () async {
        final svc = _makeService();
        final results = await svc.searchByName('บาง');
        expect(results, isNotEmpty);
        expect(
          results.any((d) => d.districtNameTh.contains('บาง')),
          isTrue,
          reason: 'Expected at least one district with "บาง" in districtNameTh',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Acceptance criterion 3: selected entry has all 6 string fields
    // -----------------------------------------------------------------------
    test(
      'selecting a district produces an object with all 6 string fields populated',
      () async {
        final svc = _makeService();
        final results = await svc.searchByName('bang');
        expect(results, isNotEmpty);
        final entry = results.first;

        // Verify all six fields exist and are non-empty strings
        expect(entry.provinceId, isA<String>());
        expect(entry.provinceId, isNotEmpty);
        expect(entry.provinceNameTh, isA<String>());
        expect(entry.provinceNameTh, isNotEmpty);
        expect(entry.provinceNameEn, isA<String>());
        expect(entry.provinceNameEn, isNotEmpty);
        expect(entry.districtId, isA<String>());
        expect(entry.districtId, isNotEmpty);
        expect(entry.districtNameTh, isA<String>());
        expect(entry.districtNameTh, isNotEmpty);
        expect(entry.districtNameEn, isA<String>());
        expect(entry.districtNameEn, isNotEmpty);
      },
    );

    test('toJson round-trips through fromJson with no data loss', () async {
      final svc = _makeService();
      final results = await svc.loadAll();
      for (final entry in results) {
        final roundTripped = DistrictEntry.fromJson(entry.toJson());
        expect(roundTripped.provinceId, entry.provinceId);
        expect(roundTripped.provinceNameTh, entry.provinceNameTh);
        expect(roundTripped.provinceNameEn, entry.provinceNameEn);
        expect(roundTripped.districtId, entry.districtId);
        expect(roundTripped.districtNameTh, entry.districtNameTh);
        expect(roundTripped.districtNameEn, entry.districtNameEn);
      }
    });

    test('empty query returns up to 50 results', () async {
      final svc = _makeService();
      final results = await svc.searchByName('');
      expect(results.length, lessThanOrEqualTo(50));
      // With our 3-entry fixture we get all 3
      expect(results, hasLength(_fixtureDistricts.length));
    });

    test('query that matches no districts returns empty list', () async {
      final svc = _makeService();
      final results = await svc.searchByName('zzznomatch999');
      expect(results, isEmpty);
    });

    test(
      'displayLabel format is "districtTh · districtEn, provinceEn"',
      () async {
        final svc = _makeService();
        final results = await svc.loadAll();
        final entry = results.first;
        final label = entry.displayLabel;
        expect(label, contains(' · '));
        expect(label, contains(', '));
        expect(label, startsWith(entry.districtNameTh));
        expect(label, contains(entry.districtNameEn));
        expect(label, endsWith(entry.provinceNameEn));
      },
    );

    test('clearCache forces re-load on next call', () async {
      var callCount = 0;
      final svc = DistrictService(
        assetLoader: (_) async {
          callCount++;
          return _fixtureJson();
        },
      );
      await svc.loadAll();
      svc.clearCache();
      await svc.loadAll();
      expect(callCount, 2);
    });
  });
}
