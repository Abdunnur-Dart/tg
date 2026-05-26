import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType { direct, group, channel }

class ChatModel {
  final String id;
  final String title;
  final ChatType type;
  final List<String> participants; // Список UID участников
  final String? adminId;           // Владелец группы/канала
  final String? lastMessage;
  final DateTime? updatedAt;

  ChatModel({
    required this.id,
    required this.title,
    required this.type,
    required this.participants,
    this.adminId,
    this.lastMessage,
    this.updatedAt,
  });

  // Преобразование из данных Firebase в объект Dart[cite: 6]
factory ChatModel.fromMap(Map<String, dynamic> map, String documentId) {
  // Безопасное получение даты
  DateTime parsedDate;
  var rawDate = map['updatedAt'];
  
  if (rawDate is Timestamp) {
    parsedDate = rawDate.toDate();
  } else if (rawDate is String) {
    parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
  } else {
    parsedDate = DateTime.now();
  }

  return ChatModel(
    id: documentId,
    title: map['title'] ?? 'Без названия',
    type: ChatType.values.firstWhere(
      (e) => e.toString().split('.').last == map['type'],
      orElse: () => ChatType.direct,
    ),
    participants: List<String>.from(map['participants'] ?? []),
    adminId: map['adminId'],
    lastMessage: map['lastMessage'],
    updatedAt: parsedDate,
  );
}

  // Подготовка данных для сохранения в Firebase[cite: 5]
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type.toString().split('.').last, // сохранит как 'direct', 'group' или 'channel'
      'participants': participants,
      'adminId': adminId,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }
}