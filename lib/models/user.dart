import 'package:cloud_firestore/cloud_firestore.dart';

/// Flat six-string district object as defined in WBS 3.6.
/// No lat/lng, no GPS coordinates.
class HomeDistrict {
  final String provinceId;
  final String provinceNameTh;
  final String provinceNameEn;
  final String districtId;
  final String districtNameTh;
  final String districtNameEn;

  const HomeDistrict({
    required this.provinceId,
    required this.provinceNameTh,
    required this.provinceNameEn,
    required this.districtId,
    required this.districtNameTh,
    required this.districtNameEn,
  });

  factory HomeDistrict.fromJson(Map<String, dynamic> json) {
    return HomeDistrict(
      provinceId: (json['provinceId'] as String?) ?? '',
      provinceNameTh: (json['provinceNameTh'] as String?) ?? '',
      provinceNameEn: (json['provinceNameEn'] as String?) ?? '',
      districtId: (json['districtId'] as String?) ?? '',
      districtNameTh: (json['districtNameTh'] as String?) ?? '',
      districtNameEn: (json['districtNameEn'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'provinceId': provinceId,
    'provinceNameTh': provinceNameTh,
    'provinceNameEn': provinceNameEn,
    'districtId': districtId,
    'districtNameTh': districtNameTh,
    'districtNameEn': districtNameEn,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeDistrict &&
          provinceId == other.provinceId &&
          provinceNameTh == other.provinceNameTh &&
          provinceNameEn == other.provinceNameEn &&
          districtId == other.districtId &&
          districtNameTh == other.districtNameTh &&
          districtNameEn == other.districtNameEn;

  @override
  int get hashCode => Object.hash(
    provinceId,
    provinceNameTh,
    provinceNameEn,
    districtId,
    districtNameTh,
    districtNameEn,
  );
}

/// User document as defined in WBS 3.6 (`/users/{userId}`).
/// No trust score, no age, no activity status.
class User {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final HomeDistrict homeDistrict;
  final String bio;
  final DateTime? createdAt;
  final int tradesCount;
  final double totalCo2Saved;
  final double totalWasteDiverted;

  const User({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.homeDistrict,
    required this.bio,
    this.createdAt,
    this.tradesCount = 0,
    this.totalCo2Saved = 0,
    this.totalWasteDiverted = 0,
  });

  factory User.fromJson(Map<String, dynamic> json, {String uid = ''}) {
    final districtJson = json['homeDistrict'] as Map<String, dynamic>?;
    return User(
      uid: uid,
      email: (json['email'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      photoUrl: (json['photoUrl'] as String?) ?? '',
      homeDistrict: districtJson != null
          ? HomeDistrict.fromJson(districtJson)
          : const HomeDistrict(
              provinceId: '',
              provinceNameTh: '',
              provinceNameEn: '',
              districtId: '',
              districtNameTh: '',
              districtNameEn: '',
            ),
      bio: (json['bio'] as String?) ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      tradesCount: (json['tradesCount'] as num?)?.toInt() ?? 0,
      totalCo2Saved: (json['totalCo2Saved'] as num?)?.toDouble() ?? 0,
      totalWasteDiverted: (json['totalWasteDiverted'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'homeDistrict': homeDistrict.toJson(),
    'bio': bio,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'tradesCount': tradesCount,
    'totalCo2Saved': totalCo2Saved,
    'totalWasteDiverted': totalWasteDiverted,
  };

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    HomeDistrict? homeDistrict,
    String? bio,
    DateTime? createdAt,
    int? tradesCount,
    double? totalCo2Saved,
    double? totalWasteDiverted,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      homeDistrict: homeDistrict ?? this.homeDistrict,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      tradesCount: tradesCount ?? this.tradesCount,
      totalCo2Saved: totalCo2Saved ?? this.totalCo2Saved,
      totalWasteDiverted: totalWasteDiverted ?? this.totalWasteDiverted,
    );
  }
}
