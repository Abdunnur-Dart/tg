// // lib/services/fcm_sender_service.dart
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart';

// class FCMSenderService {
//   static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';
  
//   // ⚠️ ВАЖНО: Замените на ваш Server Key из Firebase Console
//   // Project Settings → Cloud Messaging → Server key
//   static const String _serverKey = 'ВАШ_SERVER_KEY_ИЗ_FIREBASE_CONSOЛИ';
  
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
//   // Отправка уведомления о новом сообщении
//   Future<bool> sendMessageNotification({
//     required String targetUserId,
//     required String senderName,
//     required String messageText,
//     required String chatId,
//     required String chatTitle,
//   }) async {
//     try {
//       final token = await _getUserFCMToken(targetUserId);
//       if (token == null) {
//         print('⚠️ Нет FCM токена у пользователя $targetUserId');
//         return false;
//       }
      
//       final shortMessage = messageText.length > 100 
//           ? '${messageText.substring(0, 100)}...'
//           : messageText;
      
//       final payload = {
//         'to': token,
//         'notification': {
//           'title': senderName,
//           'body': shortMessage,
//           'sound': 'default',
//         },
//         'data': {
//           'chatId': chatId,
//           'chatTitle': chatTitle,
//           'senderName': senderName,
//           'type': 'message',
//           'click_action': 'FLUTTER_NOTIFICATION_CLICK',
//         },
//         'android': {
//           'priority': 'high',
//           'notification': {
//             'channel_id': 'telegraph_channel',
//           },
//         },
//         'apns': {
//           'payload': {
//             'aps': {
//               'sound': 'default',
//               'badge': 1,
//             },
//           },
//         },
//       };
      
//       final response = await http.post(
//         Uri.parse(_fcmUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'key=$_serverKey',
//         },
//         body: json.encode(payload),
//       );
      
//       if (response.statusCode == 200) {
//         print('✅ Уведомление отправлено пользователю $targetUserId');
//         return true;
//       } else {
//         print('❌ Ошибка отправки: ${response.body}');
//         return false;
//       }
      
//     } catch (e) {
//       print('❌ Ошибка в sendMessageNotification: $e');
//       return false;
//     }
//   }
  
//   // Отправка уведомления о звонке
//   Future<bool> sendCallNotification({
//     required String targetUserId,
//     required String callerName,
//     required String callId,
//   }) async {
//     try {
//       final token = await _getUserFCMToken(targetUserId);
//       if (token == null) return false;
      
//       final payload = {
//         'to': token,
//         'notification': {
//           'title': '📞 Входящий звонок',
//           'body': '$callerName звонит вам',
//           'sound': 'default',
//         },
//         'data': {
//           'callId': callId,
//           'callerName': callerName,
//           'type': 'call',
//           'click_action': 'FLUTTER_NOTIFICATION_CLICK',
//         },
//         'android': {
//           'priority': 'high',
//         },
//       };
      
//       final response = await http.post(
//         Uri.parse(_fcmUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'key=$_serverKey',
//         },
//         body: json.encode(payload),
//       );
      
//       return response.statusCode == 200;
      
//     } catch (e) {
//       print('❌ Ошибка отправки уведомления о звонке: $e');
//       return false;
//     }
//   }
  
//   // Отправка уведомлений всем участникам чата
//   Future<void> sendToChatParticipants({
//     required String chatId,
//     required String senderId,
//     required String senderName,
//     required String messageText,
//     required String chatTitle,
//   }) async {
//     try {
//       final chatDoc = await _firestore.collection('chats').doc(chatId).get();
//       if (!chatDoc.exists) return;
      
//       final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      
//       print('📨 Отправка уведомлений участникам чата: ${participants.length} человек');
      
//       for (final userId in participants) {
//         if (userId == senderId) continue;
        
//         await sendMessageNotification(
//           targetUserId: userId,
//           senderName: senderName,
//           messageText: messageText,
//           chatId: chatId,
//           chatTitle: chatTitle,
//         );
        
//         await Future.delayed(const Duration(milliseconds: 100));
//       }
      
//     } catch (e) {
//       print('❌ Ошибка массовой отправки: $e');
//     }
//   }
  
//   // Получение FCM токена пользователя
//   Future<String?> _getUserFCMToken(String userId) async {
//     try {
//       final doc = await _firestore
//           .collection('users_profiles')
//           .doc(userId)
//           .get();
      
//       return doc.data()?['fcmToken'] as String?;
//     } catch (e) {
//       print('❌ Ошибка получения токена: $e');
//       return null;
//     }
//   }
// }