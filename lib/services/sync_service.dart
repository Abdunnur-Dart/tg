import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../services/db_helper.dart';
import '../services/firebase_service.dart';
import '../services/encryption_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseService _firebase = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isOnline = true;
  Timer? _syncTimer;
  final List<QueuedMessage> _pendingMessages = [];
  bool _isSyncing = false;
  
  // Stream для уведомления UI об изменении статуса
  final _syncStatusController = StreamController<bool>.broadcast();
  Stream<bool> get syncStatusStream => _syncStatusController.stream;
  
  // Геттер для проверки онлайн статуса
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    await _loadQueueFromStorage();
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivityAndSync();
    });
  }

  Future<void> _checkConnectivityAndSync() async {
    final wasOnline = _isOnline;
    _isOnline = await _isConnectedToFirebase();
    
    if (_isOnline != wasOnline) {
      _syncStatusController.add(_isOnline);
      debugPrint("🔄 Статус соединения изменился: ${_isOnline ? 'Онлайн' : 'Оффлайн'}");
    }
    
    if (!wasOnline && _isOnline) {
      debugPrint("🔄 Вернулись онлайн, запускаем синхронизацию...");
      await syncAll();
    }
  }

  Future<bool> _isConnectedToFirebase() async {
    try {
      await _firestore.collection('chats').limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Отправка сообщения с поддержкой оффлайн
  Future<void> sendMessageOffline({
    required String roomId,
    required String content,
    required String username,
    required String userId,
    required String roomPassword,
  }) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Шифруем сообщение
    final encryptedContent = EncryptionService.encrypt(content, roomPassword, roomId);
    final roomKey = _hashRoomKey(roomId, roomPassword);
    
    final message = MessageModel(
      id: messageId,
      content: encryptedContent,
      username: username,
      userId: userId,
      roomId: roomId,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    // 1. Сразу сохраняем в локальную БД
    await DBHelper.saveLocal(message);
    
    // 2. Добавляем в очередь на отправку
    final queued = QueuedMessage(
      localId: messageId,
      roomId: roomId,
      roomKey: roomKey,
      content: encryptedContent,
      username: username,
      userId: userId,
      createdAt: message.createdAt,
    );
    
    _pendingMessages.add(queued);
    await _saveQueueToStorage();
    
    debugPrint("📱 Сообщение сохранено локально, в очереди: ${_pendingMessages.length}");
    
    // 3. Если онлайн — отправляем сразу
    if (_isOnline) {
      await _sendQueuedMessages();
    }
  }

  /// Синхронизация всех данных при возвращении онлайн
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint("⚠️ Синхронизация уже идёт");
      return;
    }
    
    _isSyncing = true;
    debugPrint("🔄 Начинаем полную синхронизацию...");
    
    try {
      await _sendQueuedMessages();
      await _fetchMissedMessages();
      debugPrint("✅ Синхронизация завершена");
    } catch (e) {
      debugPrint("❌ Ошибка синхронизации: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// Отправка сообщений из очереди
  Future<void> _sendQueuedMessages() async {
    if (_pendingMessages.isEmpty) return;
    
    debugPrint("📤 Отправляем ${_pendingMessages.length} сообщений из очереди...");
    
    final List<QueuedMessage> sentSuccessfully = [];
    
    for (final msg in _pendingMessages) {
      try {
        await _firestore
            .collection('chats')
            .doc(msg.roomId)
            .collection('messages')
            .add({
          'id': msg.localId,
          'room_id': msg.roomKey,
          'content': msg.content,
          'username': msg.username,
          'user_id': msg.userId,
          'created_at': msg.createdAt,
          'is_image': 0,
        });
        
        sentSuccessfully.add(msg);
        debugPrint("✅ Отправлено сообщение ${msg.localId}");
        
      } catch (e) {
        debugPrint("❌ Ошибка отправки сообщения ${msg.localId}: $e");
      }
    }
    
    // Удаляем отправленные из очереди
    _pendingMessages.removeWhere((msg) => sentSuccessfully.contains(msg));
    await _saveQueueToStorage();
    
    debugPrint("📊 Осталось в очереди: ${_pendingMessages.length}");
  }

  /// Получение пропущенных сообщений из всех чатов
  Future<void> _fetchMissedMessages() async {
    final currentUser = _firebase.currentUser;
    if (currentUser == null) return;
    
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();
    
    for (final chatDoc in chatsSnapshot.docs) {
      final chatId = chatDoc.id;
      
      final localMessages = await DBHelper.getLocal(chatId);
      final lastLocalTime = localMessages.isNotEmpty
          ? DateTime.parse(localMessages.last.createdAt)
          : DateTime.now().subtract(const Duration(days: 30));
      
      final newMessagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('created_at', isGreaterThan: lastLocalTime.toIso8601String())
          .get();
      
      for (final doc in newMessagesSnapshot.docs) {
        final data = doc.data();
        final message = MessageModel.fromMap({
          ...data,
          'id': doc.id,
        });
        await DBHelper.saveLocal(message);
      }
      
      if (newMessagesSnapshot.docs.isNotEmpty) {
        debugPrint("📥 Загружено ${newMessagesSnapshot.docs.length} новых сообщений в чате $chatId");
      }
    }
  }

  String _hashRoomKey(String roomId, String password) {
    return password.isNotEmpty 
        ? EncryptionService.deriveRoomKey(password, roomId)
        : "default_room_key_$roomId";
  }

  Future<void> _saveQueueToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queueJson = _pendingMessages.map((m) => m.toJson()).toList();
    await prefs.setStringList('pending_messages', queueJson);
  }

  Future<void> _loadQueueFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? queueJson = prefs.getStringList('pending_messages');
    if (queueJson != null) {
      _pendingMessages.clear();
      _pendingMessages.addAll(queueJson.map((json) => QueuedMessage.fromJson(json)));
      debugPrint("📂 Загружено ${_pendingMessages.length} сообщений из очереди");
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncStatusController.close();
  }
}

/// Модель сообщения в очереди
class QueuedMessage {
  final String localId;
  final String roomId;
  final String roomKey;
  final String content;
  final String username;
  final String userId;
  final String createdAt;

  QueuedMessage({
    required this.localId,
    required this.roomId,
    required this.roomKey,
    required this.content,
    required this.username,
    required this.userId,
    required this.createdAt,
  });

  String toJson() {
    return '${localId}|${roomId}|${roomKey}|${content}|${username}|${userId}|${createdAt}';
  }

  factory QueuedMessage.fromJson(String json) {
    final parts = json.split('|');
    return QueuedMessage(
      localId: parts[0],
      roomId: parts[1],
      roomKey: parts[2],
      content: parts[3],
      username: parts[4],
      userId: parts[5],
      createdAt: parts[6],
    );
  }
}