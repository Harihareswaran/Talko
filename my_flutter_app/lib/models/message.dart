import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String userId;
  final String chatId;

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    required this.userId,
    required this.chatId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp), // Store as Firestore Timestamp
      'userId': userId,
      'chatId': chatId,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      userId: map['userId'] ?? '',
      chatId: map['chatId'] ?? '',
    );
  }
}
