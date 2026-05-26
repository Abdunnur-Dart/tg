// lib/services/notification_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static String? _fcmToken;
  static bool _isInitialized = false;




static Future<void> saveTokenToFirestore(String userId) async {
  if (kIsWeb) return;
  if (_fcmToken == null || userId.isEmpty) return;
  
  try {
    print('💾 Сохраняем FCM токен для $userId: ${_fcmToken?.substring(0, 20)}...');
    await FirebaseFirestore.instance
        .collection('users_profiles')
        .doc(userId)
        .set({
          'fcmToken': _fcmToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    print('✅ FCM токен сохранён');
  } catch (e) {
    print('❌ Ошибка сохранения токена: $e');
  }
}



  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Для Web пока отключаем (можно добавить позже)
    if (kIsWeb) {
      print('⚠️ Уведомления отключены для Web');
      return;
    }
    
    try {
      // Настройка локальных уведомлений для Android
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iosSettings = 
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      
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
      print('✅ FCM Token: $_fcmToken');
      
      // Слушаем обновление токена
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('🔄 FCM токен обновлен: $newToken');
        _updateTokenInFirestore();
      });
      
      // Обработка сообщений, когда приложение открыто
      FirebaseMessaging.onMessage.listen(_showLocalNotification);
      
      // Обработка фоновых сообщений
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Обработка открытия уведомления
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      
      _isInitialized = true;
      print('✅ NotificationService инициализирован');
      
    } catch (e) {
      print('❌ Ошибка инициализации: $e');
    }
  }
  
  static Future<void> _updateTokenInFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _fcmToken != null) {
      await saveTokenToFirestore(user.uid);
    }
  }
  

  
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'telegraph_channel',
        'Telegraph Уведомления',
        channelDescription: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title,
        notification.body,
        details,
        payload: message.data['chatId'],
      );
    } catch (e) {
      print('Ошибка показа уведомления: $e');
    }
  }
  
  static void _onNotificationTap(NotificationResponse response) {
    // Обработка нажатия на уведомление
    final chatId = response.payload;
    if (chatId != null && chatId.isNotEmpty) {
      // Здесь можно навигировать в чат
      print('Нажато на уведомление чата: $chatId');
    }
  }
  
  static Future<void> _onMessageOpened(RemoteMessage message) async {
    print('👆 Открыто уведомление: ${message.data}');
    // TODO: Навигировать в соответствующий чат
  }
  
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('📬 Фоновое уведомление: ${message.notification?.title}');
  }
  
  static String? getCurrentToken() => _fcmToken;
  
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
}