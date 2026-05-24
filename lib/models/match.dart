import 'package:cloud_firestore/cloud_firestore.dart';

/// Match status values locked by WBS 3.6.
enum MatchStatus {
  active,
  completed,
  cancelled;

  String get value => name;

  static MatchStatus fromString(String s) => MatchStatus.values.firstWhere(
    (v) => v.value == s,
    orElse: () => MatchStatus.cancelled,
  );
}

/// Match document as defined in WBS 3.6 (`/matches/{matchId}`).
class Match {
  final String id;
  final String userAId;
  final String userBId;

  /// The item of B that A picked — i.e., what A wants to receive.
  final String userAWantsItemId;

  /// The item of A that B picked — i.e., what B wants to receive.
  final String userBWantsItemId;

  final MatchStatus status;

  /// [userAId, userBId] — used by Firestore security rules for array-contains queries.
  final List<String> participants;

  final DateTime? createdAt;
  final DateTime? completedAt;

  const Match({
    required this.id,
    required this.userAId,
    required this.userBId,
    required this.userAWantsItemId,
    required this.userBWantsItemId,
    required this.status,
    required this.participants,
    this.createdAt,
    this.completedAt,
  });

  factory Match.fromJson(Map<String, dynamic> json, {String id = ''}) {
    return Match(
      id: id,
      userAId: (json['userAId'] as String?) ?? '',
      userBId: (json['userBId'] as String?) ?? '',
      userAWantsItemId: (json['userAWantsItemId'] as String?) ?? '',
      userBWantsItemId: (json['userBWantsItemId'] as String?) ?? '',
      status: MatchStatus.fromString(
        (json['status'] as String?) ?? 'cancelled',
      ),
      participants: List<String>.from(json['participants'] as List? ?? []),
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

  Match copyWith({
    String? id,
    String? userAId,
    String? userBId,
    String? userAWantsItemId,
    String? userBWantsItemId,
    MatchStatus? status,
    List<String>? participants,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Match(
      id: id ?? this.id,
      userAId: userAId ?? this.userAId,
      userBId: userBId ?? this.userBId,
      userAWantsItemId: userAWantsItemId ?? this.userAWantsItemId,
      userBWantsItemId: userBWantsItemId ?? this.userBWantsItemId,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
