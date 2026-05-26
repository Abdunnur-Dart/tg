// lib/services/fcm_v1_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter/foundation.dart';

class FCMV1Service {
  static FCMV1Service? _instance;
  factory FCMV1Service() => _instance ??= FCMV1Service._();
  FCMV1Service._();
  
  static const String _projectId = 'telegraph-cbe5c';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Кэш для Access Token (токен живёт ~1 час)
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;
  
  // ------------------- ПОЛУЧЕНИЕ ACCESS TOKEN -------------------
  
  /// Получение Access Token через сервисный аккаунт
  Future<String> _getAccessToken() async {
    // Проверяем кэш
    if (_cachedAccessToken != null && 
        _tokenExpiry != null && 
        DateTime.now().isBefore(_tokenExpiry!)) {
      debugPrint('📱 Используем кэшированный токен, истекает: $_tokenExpiry');
      return _cachedAccessToken!;
    }
    
    try {
      // Загружаем сервисный аккаунт из assets
      final String jsonString = await rootBundle.loadString('assets/firebase-adminsdk.json');
      final credentials = auth.ServiceAccountCredentials.fromJson(jsonString);
      
      // Получаем клиент с токеном
      final client = await auth.clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );
      
      // Сохраняем токен
      _cachedAccessToken = client.credentials.accessToken.data;
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
      
      debugPrint('✅ Получен новый Access Token для FCM V1');
      debugPrint('📅 Истекает: $_tokenExpiry');
      
      // Закрываем клиент (токен уже сохранён)
      client.close();
      
      return _cachedAccessToken!;
      
    } catch (e) {
      debugPrint('❌ Ошибка получения Access Token: $e');
      rethrow;
    }
  }
  
  // ------------------- ОТПРАВКА УВЕДОМЛЕНИЙ -------------------
  
  /// Отправка уведомления о новом сообщении
  Future<bool> sendMessageNotification({
    required String targetUserId,
    required String senderName,
    required String messageText,
    required String chatId,
    required String chatTitle,
  }) async {
    try {
      // Не отправляем уведомление самому себе
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == targetUserId) {
        debugPrint('⚠️ Не отправляем уведомление самому себе');
        return false;
      }
      
      // Получаем FCM токен получателя
      final token = await _getUserFCMToken(targetUserId);
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ Нет FCM токена у пользователя $targetUserId');
        return false;
      }
      
      debugPrint('📱 Отправка уведомления пользователю $targetUserId');
      debugPrint('📱 Токен: ${token.substring(0, 20)}...');
      
      // Получаем Access Token
      final accessToken = await _getAccessToken();
      
      // Формируем URL для FCM v1 API
      final url = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      
      // Обрезаем длинное сообщение
      final shortMessage = messageText.length > 100 
          ? '${messageText.substring(0, 100)}...'
          : messageText;
      
      // Формируем payload по спецификации FCM v1
      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': senderName,
            'body': shortMessage,
          },
          'data': {
            'chatId': chatId,
            'chatTitle': chatTitle,
            'senderName': senderName,
            'senderId': currentUser?.uid ?? '',
            'type': 'message',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'telegraph_channel',
              'sound': 'default',
              'icon': '@mipmap/ic_launcher',
              'color': '#4CAF50',
            },
          },
          'apns': {
            'headers': {
              'apns-priority': '10',
            },
            'payload': {
              'aps': {
                'alert': {
                  'title': senderName,
                  'body': shortMessage,
                },
                'sound': 'default',
                'badge': 1,
              },
            },
          },
        },
      };
      
      // Отправляем запрос
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ FCM уведомление отправлено пользователю $targetUserId');
        debugPrint('📨 Ответ: ${response.body}');
        return true;
      } else {
        debugPrint('❌ Ошибка FCM: ${response.statusCode}');
        debugPrint('📨 Ответ: ${response.body}');
        
        // Если ошибка 404 или токен недействителен
        if (response.statusCode == 404 || 
            response.body.contains('InvalidRegistration') ||
            response.body.contains('NotRegistered') ||
            response.body.contains('UNREGISTERED')) {
          await _removeInvalidToken(targetUserId);
        }
        
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Ошибка отправки уведомления: $e');
      return false;
    }
  }
  
  /// Отправка уведомления о звонке
  Future<bool> sendCallNotification({
    required String targetUserId,
    required String callerName,
    required String callId,
  }) async {
    try {
      final token = await _getUserFCMToken(targetUserId);
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ Нет токена для звонка пользователю $targetUserId');
        return false;
      }
      
      final accessToken = await _getAccessToken();
      final url = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
      
      final payload = {
        'message': {
          'token': token,
          'notification': {
            'title': '📞 Входящий звонок',
            'body': '$callerName звонит вам',
          },
          'data': {
            'callId': callId,
            'callerName': callerName,
            'type': 'call',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'telegraph_channel',
              'sound': 'default',
              'icon': '@mipmap/ic_launcher',
            },
          },
          'apns': {
            'payload': {
              'aps': {
                'alert': {
                  'title': '📞 Входящий звонок',
                  'body': '$callerName звонит вам',
                },
                'sound': 'default',
                'badge': 1,
              },
            },
          },
        },
      };
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Уведомление о звонке отправлено пользователю $targetUserId');
        return true;
      } else {
        debugPrint('❌ Ошибка звонка: ${response.statusCode}');
        debugPrint('📨 Ответ: ${response.body}');
        return false;
      }
      
    } catch (e) {
      debugPrint('❌ Ошибка уведомления о звонке: $e');
      return false;
    }
  }
  
  // ------------------- МАССОВАЯ ОТПРАВКА -------------------
  
  /// Отправка уведомлений всем участникам чата (кроме отправителя)
  Future<Map<String, int>> sendToChatParticipants({
    required String chatId,
    required String senderId,
    required String senderName,
    required String messageText,
    required String chatTitle,
  }) async {
    final Map<String, int> result = {'sent': 0, 'failed': 0};
    
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        debugPrint('❌ Чат $chatId не найден');
        return result;
      }
      
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      
      debugPrint('📨 Отправка уведомлений ${participants.length} участникам чата "$chatTitle"');
      
      for (final userId in participants) {
        if (userId == senderId) continue; // Пропускаем отправителя
        
        final success = await sendMessageNotification(
          targetUserId: userId,
          senderName: senderName,
          messageText: messageText,
          chatId: chatId,
          chatTitle: chatTitle,
        );
        
        if (success) {
          result['sent'] = result['sent']! + 1;
        } else {
          result['failed'] = result['failed']! + 1;
        }
        
        // Небольшая задержка, чтобы не перегружать API
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      debugPrint('📊 Итог: отправлено ${result['sent']}, ошибок ${result['failed']}');
      
    } catch (e) {
      debugPrint('❌ Ошибка массовой отправки: $e');
    }
    
    return result;
  }
  
  // ------------------- РАБОТА С ТОКЕНАМИ -------------------
  
  /// Получение FCM токена пользователя из Firestore
  Future<String?> _getUserFCMToken(String userId) async {
    try {
      final doc = await _firestore
          .collection('users_profiles')
          .doc(userId)
          .get();
      
      final token = doc.data()?['fcmToken'] as String?;
      
      if (token != null && token.isNotEmpty) {
        debugPrint('📱 Найден токен для $userId: ${token.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ Нет токена для $userId');
      }
      
      return token;
    } catch (e) {
      debugPrint('❌ Ошибка получения токена для $userId: $e');
      return null;
    }
  }
  
  /// Удаление недействительного токена
  Future<void> _removeInvalidToken(String userId) async {
    try {
      await _firestore
          .collection('users_profiles')
          .doc(userId)
          .update({
            'fcmToken': FieldValue.delete(),
            'fcmTokenInvalidAt': FieldValue.serverTimestamp(),
          });
      debugPrint('🗑️ Удалён недействительный токен для $userId');
    } catch (e) {
      debugPrint('⚠️ Не удалось удалить токен: $e');
    }
  }
  
  // ------------------- ДИАГНОСТИКА -------------------
  
  /// Получить статистику (сколько пользователей имеют токены)
  Future<int> getUsersWithTokensCount() async {
    try {
      final snapshot = await _firestore
          .collection('users_profiles')
          .where('fcmToken', isNotEqualTo: null)
          .get();
      debugPrint('📊 Пользователей с FCM токенами: ${snapshot.docs.length}');
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Ошибка получения статистики: $e');
      return 0;
    }
  }
  
  /// Проверить, есть ли токен у текущего пользователя
  Future<bool> hasCurrentUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    final token = await _getUserFCMToken(user.uid);
    return token != null && token.isNotEmpty;
  }
  
  /// Принудительное обновление токена (для отладки)
  Future<void> refreshTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ Пользователь не авторизован');
      return;
    }
    
    // Очищаем кэш токена
    _cachedAccessToken = null;
    _tokenExpiry = null;
    
    // Пробуем отправить тестовое уведомление
    final success = await sendMessageNotification(
      targetUserId: user.uid,
      senderName: "Тест",
      messageText: "Тестовое уведомление",
      chatId: "test",
      chatTitle: "Тест",
    );
    
    debugPrint(success 
        ? '✅ Токен работает' 
        : '❌ Токен не работает, нужна диагностика');
  }
}