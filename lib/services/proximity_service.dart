import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ecoswap/models/user.dart';

/// Bucket labels for proximity between two users.
/// Ordered from most-relevant to least-relevant.
enum ProximityBucket {
  sameDistrict,
  sameProvince,
  nearbyProvinces,
  allThailand,
}

/// Scores proximity between two users using bucket-based logic.
///
/// No GPS, no lat/lng, no kilometre math. Two users are scored by comparing
/// their [homeDistrict] fields against a hand-curated [nearby_provinces.json]
/// adjacency table.
///
/// Use [ProximityService.load()] to obtain an instance with the JSON table
/// pre-loaded. Inject a pre-loaded instance in tests to avoid platform assets.
class ProximityService {
  /// Key: provinceId string, value: list of adjacent provinceId strings.
  final Map<String, List<String>> _nearbyProvinces;

  /// Internal constructor. Use [ProximityService.load()] or
  /// [ProximityService.withTable()] (for tests).
  ProximityService._(this._nearbyProvinces);

  /// Loads [nearby_provinces.json] from assets and returns a ready service.
  static Future<ProximityService> load() async {
    final raw = await rootBundle
        .loadString('assets/data/nearby_provinces.json');
    return ProximityService._(_parseJson(raw));
  }

  /// Constructs a service from a pre-built table. Use in unit tests.
  factory ProximityService.withTable(Map<String, List<String>> table) {
    return ProximityService._(Map.unmodifiable(table));
  }

  static Map<String, List<String>> _parseJson(String raw) {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final result = <String, List<String>>{};
    for (final entry in decoded.entries) {
      // Skip comment keys
      if (entry.key.startsWith('_')) continue;
      final list = entry.value;
      if (list is List) {
        result[entry.key] =
            List<String>.unmodifiable(list.map((e) => e.toString()));
      }
    }
    return Map.unmodifiable(result);
  }

  /// Returns the proximity bucket between user [a] and user [b].
  ///
  /// Rules (in priority order):
  /// 1. Identical [districtId] → [ProximityBucket.sameDistrict]
  /// 2. Same [provinceId], different district → [ProximityBucket.sameProvince]
  /// 3. B's province is in A's adjacency list → [ProximityBucket.nearbyProvinces]
  /// 4. Otherwise → [ProximityBucket.allThailand]
  ProximityBucket bucketFor(User a, User b) {
    final aDistrict = a.homeDistrict;
    final bDistrict = b.homeDistrict;

    if (aDistrict.districtId == bDistrict.districtId) {
      return ProximityBucket.sameDistrict;
    }

    if (aDistrict.provinceId == bDistrict.provinceId) {
      return ProximityBucket.sameProvince;
    }

    final neighbours = _nearbyProvinces[aDistrict.provinceId] ?? const [];
    if (neighbours.contains(bDistrict.provinceId)) {
      return ProximityBucket.nearbyProvinces;
    }

    return ProximityBucket.allThailand;
  }

  /// Exposes the loaded neighbour table (read-only). Used in tests to verify
  /// the JSON was parsed correctly.
  Map<String, List<String>> get nearbyProvinces => _nearbyProvinces;
}
