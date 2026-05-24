import 'package:cloud_firestore/cloud_firestore.dart';

/// Match status values as defined in WBS 3.6.
enum MatchStatus {
  active,
  completed,
  cancelled;

  String get value => name;

  static MatchStatus fromString(String s) {
    return MatchStatus.values.firstWhere(
      (v) => v.value == s,
      orElse: () => MatchStatus.active,
    );
  }
}

/// Match document as defined in WBS 3.6 (`/matches/{matchId}`).
///
/// No GPS, no trust score, no activity status.
class MatchModel {
  final String id;
  final String userAId;
  final String userBId;

  /// Item that user A wants (from B's items).
  final String userAWantsItemId;

  /// Item that user B wants (from A's items).
  final String userBWantsItemId;

  final MatchStatus status;

  /// [userAId, userBId] — used by Firestore security rules.
  final List<String> participants;

  final DateTime? createdAt;
  final DateTime? completedAt;

  const MatchModel({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.userAWantsItemId,
    required this.userBWantsItemId,
    this.status = MatchStatus.active,
    this.participants = const [],
    this.createdAt,
    this.completedAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json, {String id = ''}) {
    final participantsRaw = json['participants'];
    final participants = participantsRaw is List
        ? participantsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return MatchModel(
      id: id,
      userAId: (json['userAId'] as String?) ?? '',
      userBId: (json['userBId'] as String?) ?? '',
      userAWantsItemId: (json['userAWantsItemId'] as String?) ?? '',
      userBWantsItemId: (json['userBWantsItemId'] as String?) ?? '',
      status: MatchStatus.fromString((json['status'] as String?) ?? 'active'),
      participants: participants,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      completedAt: json['completedAt'] is Timestamp
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'userAId': userAId,
    'userBId': userBId,
    'userAWantsItemId': userAWantsItemId,
    'userBWantsItemId': userBWantsItemId,
    'status': status.value,
    'participants': participants,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'completedAt': completedAt != null
        ? Timestamp.fromDate(completedAt!)
        : null,
  };
}
