// lib/services/direct_notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DirectNotificationService {
  static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';
  
  // Ваш Server Key из консоли Firebase
  // Project Settings -> Cloud Messaging -> Server key
  static const String _serverKey = 'ВАШ_SERVER_KEY_ИЗ_FIREBASE_CONSOLE';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Отправка уведомления о новом сообщении
  Future<void> sendMessageNotification({
    required String targetUserId,
    required String senderName,
    required String messageText,
    required String chatId,
    required String chatTitle,
  }) async {
    try {
      // Получаем FCM токен получателя
      final token = await _getUserFCMToken(targetUserId);
      if (token == null) {
        print("⚠️ У пользователя $targetUserId нет FCM токена");
        return;
      }
      
      // Формируем payload
      final Map<String, dynamic> notification = {
        'to': token,
        'notification': {
          'title': senderName,
          'body': messageText.length > 100 
              ? messageText.substring(0, 100) + '...' 
              : messageText,
          'sound': 'default',
          'badge': 1,
        },
        'data': {
          'chatId': chatId,
          'chatTitle': chatTitle,
          'senderId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'senderName': senderName,
          'type': 'message',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'telegraph_channel',
            'sound': 'default',
          },
        },
        'apns': {
          'payload': {
            'aps': {
              'sound': 'default',
              'badge': 1,
            },
          },
        },
      };
      
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: json.encode(notification),
      );
      
      if (response.statusCode == 200) {
        print("✅ Уведомление отправлено пользователю $targetUserId");
      } else {
        print("❌ Ошибка отправки: ${response.body}");
      }
      
    } catch (e) {
      print("❌ Ошибка при отправке уведомления: $e");
    }
  }
  
  /// Отправка уведомления о звонке
  Future<void> sendCallNotification({
    required String targetUserId,
    required String callerName,
    required String callId,
  }) async {
    try {
      final token = await _getUserFCMToken(targetUserId);
      if (token == null) return;
      
      final Map<String, dynamic> notification = {
        'to': token,
        'notification': {
          'title': '📞 Входящий звонок',
          'body': '$callerName звонит вам',
          'sound': 'default',
        },
        'data': {
          'callId': callId,
          'callerId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'callerName': callerName,
          'type': 'call',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'android': {
          'priority': 'high',
        },
      };
      
      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: json.encode(notification),
      );
      
      if (response.statusCode == 200) {
        print("✅ Уведомление о звонке отправлено");
      }
      
    } catch (e) {
      print("❌ Ошибка отправки уведомления о звонке: $e");
    }
  }
  
  /// Получение FCM токена пользователя из Firestore
  Future<String?> _getUserFCMToken(String userId) async {
    try {
      final doc = await _firestore
          .collection('users_profiles')
          .doc(userId)
          .get();
      
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      print("Ошибка получения токена: $e");
      return null;
    }
  }
  
  /// Массовая отправка уведомлений всем участникам чата (кроме отправителя)
  Future<void> sendNotificationToChatParticipants({
    required String chatId,
    required String senderId,
    required String senderName,
    required String messageText,
    required String chatTitle,
  }) async {
    try {
      // Получаем всех участников чата
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;
      
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      
      // Отправляем каждому участнику, кроме отправителя
      for (final userId in participants) {
        if (userId == senderId) continue;
        
        await sendMessageNotification(
          targetUserId: userId,
          senderName: senderName,
          messageText: messageText,
          chatId: chatId,
          chatTitle: chatTitle,
        );
        
        // Небольшая задержка, чтобы не перегружать API
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
    } catch (e) {
      print("Ошибка массовой отправки: $e");
    }
  }
}