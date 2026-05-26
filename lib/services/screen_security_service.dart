// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static String? _fcmToken;
  
  static Future<void> initialize() async {
    // Если Web - просто выходим, не инициализируем
    if (kIsWeb) {
      print('⚠️ Уведомления отключены для Web. Для тестирования используйте Android или iOS.');
      return;
    }
    
    // Только для мобильных платформ
    try {
      // Настройка уведомлений для Android
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iosSettings = 
          DarwinInitializationSettings();
      
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(settings);
      
      // Запрос разрешений для iOS
      if (Platform.isIOS) {
        await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      
      // Получение токена
      _fcmToken = await _fcm.getToken();
      print('📱 FCM Token: $_fcmToken');
      
      // Слушаем обновление токена
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('🔄 FCM токен обновлен: $newToken');
      });
      
      // Обработка сообщений
      FirebaseMessaging.onMessage.listen((message) {
        print('📬 Уведомление: ${message.notification?.title}');
        _showLocalNotification(message);
      });
      
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('👆 Нажато на уведомление');
      });
      
      print('✅ NotificationService инициализирован (мобильная версия)');
      
    } catch (e) {
      print('❌ Ошибка инициализации: $e');
    }
  }
  
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'telegraph_channel',
        'Telegraph Уведомления',
        channelDescription: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        priority: Priority.high,
      );
      
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        message.notification?.title ?? 'Telegraph',
        message.notification?.body ?? 'Новое сообщение',
        details,
      );
    } catch (e) {
      print('Ошибка показа уведомления: $e');
    }
  }
  
  static Future<void> saveTokenToFirestore(String userId) async {
    if (kIsWeb) return;
    if (_fcmToken == null || userId.isEmpty) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users_profiles')
          .doc(userId)
          .set({
            'fcmToken': _fcmToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      print('✅ FCM токен сохранен для $userId');
    } catch (e) {
      print('❌ Ошибка сохранения: $e');
    }
  }
  
  static Future<void> deleteTokenFromFirestore(String userId) async {
    if (kIsWeb) return;
    if (userId.isEmpty) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users_profiles')
          .doc(userId)
          .update({
            'fcmToken': FieldValue.delete(),
          });
      print('✅ FCM токен удален');
    } catch (e) {
      print('Ошибка удаления: $e');
    }
  }
  
  static String? getCurrentToken() => _fcmToken;
}