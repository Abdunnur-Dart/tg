import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String content;
  final String username;
  final String userId;
  final String roomId;
  final String createdAt;
  final int isImage;

  MessageModel({
    required this.id,
    required this.content,
    required this.username,
    required this.userId,
    required this.roomId,
    required this.createdAt,
    this.isImage = 0,
  });

  // Превращаем в Map для записи в локальную БД (SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'username': username,
      'user_id': userId,
      'room_id': roomId,
      'created_at': createdAt,
      'is_image': isImage,
    };
  }

  MessageModel copyWith({String? content}) {
    return MessageModel(
      id: id,
      content: content ?? this.content,
      username: username,
      userId: userId,
      roomId: roomId,
      createdAt: createdAt,
      isImage: isImage,
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    String time;
    final dynamic rawDate = map['created_at'];

    if (rawDate is Timestamp) {
      time = rawDate.toDate().toIso8601String();
    } else if (rawDate != null) {
      time = rawDate.toString();
    } else {
      time = DateTime.now().toIso8601String();
    }

    return MessageModel(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      username: map['username'] ?? 'User',
      userId: map['user_id'] ?? '',
      roomId: map['room_id'] ?? '',
      createdAt: time,
      isImage: map['is_image'] ?? 0,
    );
  }
}