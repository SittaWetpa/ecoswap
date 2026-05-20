import 'dart:convert';

import 'package:flutter/services.dart';

/// A single district entry from the flattened kongvut/thai-province-data JSON.
///
/// Matches the schema in WBS 5.2 and the homeDistrict sub-object in WBS 3.6.
/// All six fields are strings, no lat/lng or distance fields.
class DistrictEntry {
  final String provinceId;
  final String provinceNameTh;
  final String provinceNameEn;
  final String districtId;
  final String districtNameTh;
  final String districtNameEn;

  const DistrictEntry({
    required this.provinceId,
    required this.provinceNameTh,
    required this.provinceNameEn,
    required this.districtId,
    required this.districtNameTh,
    required this.districtNameEn,
  });

  factory DistrictEntry.fromJson(Map<String, dynamic> json) {
    return DistrictEntry(
      provinceId: json['provinceId'] as String,
      provinceNameTh: json['provinceNameTh'] as String,
      provinceNameEn: json['provinceNameEn'] as String,
      districtId: json['districtId'] as String,
      districtNameTh: json['districtNameTh'] as String,
      districtNameEn: json['districtNameEn'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provinceId': provinceId,
      'provinceNameTh': provinceNameTh,
      'provinceNameEn': provinceNameEn,
      'districtId': districtId,
      'districtNameTh': districtNameTh,
      'districtNameEn': districtNameEn,
    };
  }

  /// Display format: "districtNameTh · districtNameEn, provinceNameEn"
  /// Example: "เขตบางรัก · Khet Bang Rak, Bangkok"
  String get displayLabel =>
      '$districtNameTh · $districtNameEn, $provinceNameEn';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistrictEntry &&
          runtimeType == other.runtimeType &&
          districtId == other.districtId;

  @override
  int get hashCode => districtId.hashCode;
}

/// Service that loads and searches the bundled Thai district data.
///
/// Call [loadAll] once at startup (or lazily on first use) and then use
/// [searchByName] for in-memory filtering. There are no network calls.
class DistrictService {
  List<DistrictEntry>? _cache;

  /// Asset loader override — injectable for tests so they can supply a fake
  /// loader without touching the Flutter asset bundle.
  final Future<String> Function(String path)? _assetLoader;

  DistrictService({Future<String> Function(String path)? assetLoader})
      : _assetLoader = assetLoader;

  /// Loads all districts from the bundled JSON asset.
  ///
  /// The result is cached in memory; subsequent calls return the same list.
  Future<List<DistrictEntry>> loadAll() async {
    if (_cache != null) return _cache!;

    final loader = _assetLoader;
    final raw = loader != null
        ? await loader('assets/data/thai_provinces.json')
        : await rootBundle.loadString('assets/data/thai_provinces.json');

    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(DistrictEntry.fromJson)
        .toList(growable: false);

    _cache = list;
    return list;
  }

  /// Returns all districts whose Thai or English name (district or province)
  /// contains [query] (case-insensitive for English, exact substring for Thai).
  ///
  /// Returns an empty list if [query] is blank. Loads the data lazily if
  /// [loadAll] has not been called yet.
  ///
  /// Results are limited to 50 entries to keep the list manageable.
  Future<List<DistrictEntry>> searchByName(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      final all = await loadAll();
      return all.take(50).toList();
    }

    final all = await loadAll();
    final qLower = q.toLowerCase();

    return all.where((d) {
      return d.districtNameEn.toLowerCase().contains(qLower) ||
          d.districtNameTh.contains(q) ||
          d.provinceNameEn.toLowerCase().contains(qLower) ||
          d.provinceNameTh.contains(q);
    }).take(50).toList();
  }

  /// Clears the in-memory cache. Useful in tests to force a reload.
  void clearCache() {
    _cache = null;
  }
}
