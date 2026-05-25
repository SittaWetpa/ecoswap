import 'package:cloud_firestore/cloud_firestore.dart';

/// Message document as defined in WBS 3.6
/// (`/matches/{matchId}/messages/{messageId}`).
///
/// No activity status, no GPS, no trust score.
class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;
  final List<String> readBy;

  const Message({
    required this.id,
    required this.senderId,
    required this.text,
    this.sentAt,
    this.readBy = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json, {String id = ''}) {
    final readByRaw = json['readBy'];
    final readBy = readByRaw is List
        ? readByRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Message(
      id: id,
      senderId: (json['senderId'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      sentAt: json['sentAt'] is Timestamp
          ? (json['sentAt'] as Timestamp).toDate()
          : null,
      readBy: readBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'senderId': senderId,
    'text': text,
    'sentAt': sentAt != null
        ? Timestamp.fromDate(sentAt!)
        : FieldValue.serverTimestamp(),
    'readBy': readBy,
  };
}
