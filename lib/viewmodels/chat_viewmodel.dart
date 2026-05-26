import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:chat/services/secure_storage_service.dart';
import 'package:chat/viewmodels/utils/crypto_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/db_helper.dart';
import '../services/firebase_service.dart';
import '../services/encryption_service.dart'; 
import 'app_config_viewmodel.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/fcm_v1_service.dart';
import '../services/sync_service.dart';

class ChatViewModel with ChangeNotifier {
  bool get isOnline => _syncService.isOnline;
  late final SyncService _syncService;
  final String roomId;
  final AppConfigViewModel conf;
  final _firebase = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MessageModel> displayMsgs = [];
  StreamSubscription? _sub;
  List<ChatModel> myChats = [];
  final Map<String, String> _userNicknamesCache = {};
  // final FCMSenderService _fcmSender = FCMSenderService();
 final FCMV1Service _fcmSender = FCMV1Service(); // ✅ ОСТАВИТЬ ТОЛЬКО ЭТОТ
  // Переменные для безопасности
  String _chatAdminId = ""; // ID администратора чата
  
  ChatViewModel(this.roomId, this.conf) { 
    _initViewModel(); 
  }

  // ==================== ИНИЦИАЛИЗАЦИЯ ====================
  
  void _initViewModel() async {
      _syncService = SyncService();
    final roomPassword = conf.roomPasswords[roomId] ?? "";
    
    // Загружаем информацию о чате (кто администратор)
    await _loadChatInfo();
    
    // Загружаем из локальной БД
    final localRaw = await DBHelper.getLocal(roomId);
    List<MessageModel> decryptedMsgs = [];

    for (var m in localRaw) {
      String realNick = await _getVerifiedNickname(m.userId, m.username);
      decryptedMsgs.add(MessageModel(
        id: m.id,
        content: EncryptionService.decrypt(m.content, roomPassword, roomId),
        username: realNick,
        userId: m.userId,
        roomId: m.roomId,
        createdAt: m.createdAt,
        isImage: m.isImage,
      ));
    }
   
    displayMsgs = decryptedMsgs;
    notifyListeners();
    
    // Подписка на Firebase
    final rKey = conf.hashRoomKey(roomId, roomPassword);
    _sub = _firebase.getMessagesStream(rKey).listen((msgs) async {
      List<MessageModel> updatedList = [];

      for (var m in msgs) { 
        await DBHelper.saveLocal(m); 
        String verifiedNick = await _getVerifiedNickname(m.userId, m.username);

        updatedList.add(MessageModel(
          id: m.id,
          content: EncryptionService.decrypt(m.content, roomPassword, roomId),
          username: verifiedNick,
          userId: m.userId,
          roomId: m.roomId,
          createdAt: m.createdAt,
          isImage: m.isImage,
        ));
      }
      
      displayMsgs = updatedList;
      notifyListeners();
    });
  }

  // Загружает информацию о чате из Firestore
  Future<void> _loadChatInfo() async {
    try {
      final doc = await _firestore.collection('chats').doc(roomId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _chatAdminId = data['adminId'] ?? "";
        debugPrint("👑 Администратор чата: $_chatAdminId");
      }
    } catch (e) {
      debugPrint("Ошибка загрузки информации о чате: $e");
    }
  }












  // ==================== РАБОТА С ЧАТАМИ ====================

  // Слушаем чаты пользователя
  void listenToMyChats(String currentUserId) {
    _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((snapshot) {
      myChats = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  // Вступление в чат по ID
  Future<void> joinChatByCode(String chatId, String currentUserId) async {
    try {
      await _firestore.collection('chats').doc(chatId.trim()).update({
        'participants': FieldValue.arrayUnion([currentUserId])
      });
      notifyListeners();
    } catch (e) {
      debugPrint("Ошибка вступления: $e");
      rethrow;
    }
  }

  // Создание нового чата
// В файле chat_viewmodel.dart, внутри класса ChatViewModel

/// Создание нового чата с автоматической генерацией пароля
Future<void> createNewChat(ChatModel chat) async {
  try {
    print("🚀 Создаём новый чат: ${chat.title}");
    
    // 1. ГЕНЕРИРУЕМ КРИПТОСТОЙКИЙ ПАРОЛЬ ДЛЯ КОМНАТЫ
    final String roomPassword = CryptoUtils.generateStrongPassword(length: 32);
    final String roomKey = conf.hashRoomKey(chat.id, roomPassword);
    
    // 2. СОЗДАЁМ ЧАТ В FIRESTORE с указанием adminId
    final chatData = {
      'title': chat.title,
      'type': chat.type.toString().split('.').last,
      'participants': chat.participants,
      'adminId': conf.userId, // Текущий пользователь - администратор
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    final docRef = await FirebaseFirestore.instance
        .collection('chats')
        .add(chatData);
    
    final String newChatId = docRef.id;
    print("✅ Чат создан с ID: $newChatId");
    
    // 3. СОХРАНЯЕМ ПАРОЛЬ В ЛОКАЛЬНОЕ БЕЗОПАСНОЕ ХРАНИЛИЩЕ
    await SecureStorageService.saveRoomPassword(newChatId, roomPassword);
    
    // 4. ОБНОВЛЯЕМ ЛОКАЛЬНЫЙ КЭШ В ViewModel
    conf.roomPasswords[newChatId] = roomPassword;
    
    // 5. ОТПРАВЛЯЕМ СИСТЕМНОЕ СООБЩЕНИЕ (опционально)
    await _sendRoomCreatedMessage(newChatId, roomKey);
    
    print("🔐 Пароль для комнаты сохранён локально");
    notifyListeners();
    
  } catch (e) {
    print("❌ Ошибка создания чата: $e");
    rethrow;
  }
}

/// Отправка системного сообщения о создании чата
Future<void> _sendRoomCreatedMessage(String chatId, String roomKey) async {
  try {
    final roomPassword = conf.roomPasswords[chatId] ?? "";
    final encryptedMessage = EncryptionService.encrypt(
      "🆕 Чат создан. Пароль для входа сохранён локально.", 
      roomPassword, 
      chatId
    );
    
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'content': encryptedMessage,
      'room_id': roomKey,
      'username': "System",
      'user_id': "system_${DateTime.now().millisecondsSinceEpoch}",
      'created_at': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print("⚠️ Не удалось отправить системное сообщение: $e");
  }
}







/// Создаёт пригласительную ссылку с зашифрованным паролем
Future<String> generateInviteLink(String chatId) async {
  try {
    // Проверяем, что пользователь - администратор
    if (!isAdmin) {
      throw Exception("Только администратор может приглашать");
    }
    
    final roomPassword = conf.roomPasswords[chatId];
    if (roomPassword == null) {
      throw Exception("Пароль комнаты не найден");
    }
    
    // Шифруем пароль публичным ключом или простым алгоритмом
    // Упрощённая версия: просто кодируем в Base64
    final encodedPassword = base64Url.encode(utf8.encode(roomPassword));
    
    // Формируем ссылку: telegraph://join?chatId=xxx&key=yyy
    return "telegraph://join?chatId=$chatId&key=$encodedPassword";
    
  } catch (e) {
    print("❌ Ошибка создания ссылки: $e");
    rethrow;
  }
}



















/// Поиск пользователей по нику (для добавления в чат)
Future<List<Map<String, dynamic>>> searchUsersByNickname(String nickname) async {
  try {
    if (nickname.length < 3) {
      throw Exception("Введите минимум 3 символа");
    }
    
    final querySnapshot = await _firestore
        .collection('users_profiles')
        .where('nickname', isGreaterThanOrEqualTo: nickname)
        .where('nickname', isLessThanOrEqualTo: '$nickname\uf8ff')
        .limit(10)
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'nickname': data['nickname'] ?? 'Unknown',
        'email': data['email'] ?? '',
      };
    }).toList();
  } catch (e) {
    debugPrint("Ошибка поиска: $e");
    return [];
  }
}

/// Добавление пользователя по UID
Future<void> addUserByUid(String chatId, String userUid) async {
  try {
    // Проверяем права администратора
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) throw Exception("Чат не найден");
    
    final chatData = chatDoc.data() as Map<String, dynamic>;
    if (chatData['adminId'] != conf.userId) {
      throw Exception("Только администратор может добавлять участников");
    }
    
    // Проверяем, не превышен ли лимит
    final participants = List<String>.from(chatData['participants'] ?? []);
    if (participants.length >= 100) {
      throw Exception("Достигнут лимит участников (100)");
    }
    
    if (participants.contains(userUid)) {
      throw Exception("Пользователь уже в чате");
    }
    
    // Добавляем
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayUnion([userUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await _sendSystemMessage(chatId, userUid);
    
  } catch (e) {
    rethrow;
  }
}













// В chat_viewmodel.dart

/// Генерирует invite-код для чата
Future<String> generateInviteCode(String chatId) async {
  try {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) throw Exception("Чат не найден");
    
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final String? adminId = chatData['adminId'];
    
    // Только админ может генерировать код
    if (adminId != conf.userId) {
      throw Exception("Только администратор может создавать invite-код");
    }
    
    // Генерируем короткий код (например, из 6 символов)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789';
    final random = Random.secure();
    String code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
    
    // Сохраняем код в документ чата
    await _firestore.collection('chats').doc(chatId).update({
      'inviteCode': code,
      'inviteCodeCreatedAt': FieldValue.serverTimestamp(),
      'inviteCodeExpiresAt': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    });
    
    return code;
  } catch (e) {
    debugPrint("Ошибка генерации кода: $e");
    rethrow;
  }
}

/// Вход по invite-коду
Future<void> joinByInviteCode(String code, String currentUserId) async {
  try {
    // Ищем чат с таким кодом
    final querySnapshot = await _firestore
        .collection('chats')
        .where('inviteCode', isEqualTo: code.trim())
        .limit(1)
        .get();
    
    if (querySnapshot.docs.isEmpty) {
      throw Exception("Неверный код приглашения");
    }
    
    final chatDoc = querySnapshot.docs.first;
    final chatData = chatDoc.data();
    final String chatId = chatDoc.id;
    
    // Проверяем, не истёк ли код
    final expiresAt = chatData['inviteCodeExpiresAt'];
    if (expiresAt != null) {
      final expiryDate = DateTime.parse(expiresAt);
      if (DateTime.now().isAfter(expiryDate)) {
        throw Exception("Код приглашения истёк");
      }
    }
    
    // Проверяем, не состоит ли уже пользователь
    final participants = List<String>.from(chatData['participants'] ?? []);
    if (participants.contains(currentUserId)) {
      throw Exception("Вы уже состоите в этом чате");
    }
    
    // Добавляем пользователя
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayUnion([currentUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Отправляем системное сообщение
    await _sendSystemMessage(chatId, currentUserId);
    
    debugPrint("✅ Пользователь присоединился по коду $code");
    
  } catch (e) {
    debugPrint("Ошибка входа по коду: $e");
    rethrow;
  }
}














/// Вступление в чат по ID и паролю
Future<void> joinChatWithPassword(String chatId, String password) async {
  try {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    
    if (!chatDoc.exists) {
      throw Exception("Чат не найден");
    }
    
    // ПРОВЕРКА ПАРОЛЯ: пытаемся хэшировать и получить ключ
    conf.hashRoomKey(chatId, password);
    
    // Сохраняем пароль (если дошло до сюда - пароль принят)
    await SecureStorageService.saveRoomPassword(chatId, password);
    conf.roomPasswords[chatId] = password;
    
    // Добавляем пользователя
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .update({
      'participants': FieldValue.arrayUnion([conf.userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
  } catch (e) {
    throw Exception("Неверный пароль или чат не найден");
  }
}




  // ==================== ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ ====================
  
  /// Добавляет пользователя в чат по его email
  /// Только администратор чата может добавлять участников
  Future<void> addUserToChat(String chatId, String userEmail) async {
    try {
      // 1. ПРОВЕРКА: Только администратор может добавлять участников
      final currentUserId = conf.userId;
      
      // Получаем информацию о чате
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      
      if (!chatDoc.exists) {
        throw Exception("Чат не найден");
      }
      
      final chatData = chatDoc.data() as Map<String, dynamic>;
      final String? adminId = chatData['adminId'];
      
      // Проверяем, является ли текущий пользователь администратором
      if (adminId != currentUserId) {
        throw Exception("Только администратор чата может добавлять участников");
      }
      
      // 2. Проверяем, не превышен ли лимит участников
      final List<dynamic> participants = chatData['participants'] ?? [];
      const int maxParticipants = 100;
      
      if (participants.length >= maxParticipants) {
        throw Exception("Достигнут лимит участников ($maxParticipants)");
      }
      
      // 3. Ищем пользователя по Email
      final userQuery = await _firestore
          .collection('users_profiles')
          .where('email', isEqualTo: userEmail.trim().toLowerCase())
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception("Пользователь с email '$userEmail' не найден");
      }

      final newUserUid = userQuery.docs.first.id;
      
      // 4. Проверяем, не состоит ли пользователь уже в чате
      if (participants.contains(newUserUid)) {
        throw Exception("Пользователь уже состоит в этом чате");
      }
      
      // 5. Добавляем пользователя в чат
      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayUnion([newUserUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // 6. Отправляем системное сообщение
      await _sendSystemMessage(chatId, newUserUid);
      
      print("✅ Пользователь $newUserUid успешно добавлен в чат $chatId");
      
    } catch (e) {
      print("❌ Ошибка при добавлении пользователя: $e");
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception("Не удалось добавить пользователя. Попробуйте позже.");
      }
    }
  }

  // Отправка системного сообщения о новом участнике
  Future<void> _sendSystemMessage(String chatId, String newUserUid) async {
    try {
      final userProfile = await _firestore
          .collection('users_profiles')
          .doc(newUserUid)
          .get();
      
      String nickname = userProfile.data()?['nickname'] ?? 'Пользователь';
      
      final roomPassword = conf.roomPasswords[chatId] ?? "";
      final encryptedMessage = EncryptionService.encrypt(
        "👤 $nickname присоединился к чату", 
        roomPassword, 
        chatId
      );
      
      final roomKey = conf.hashRoomKey(chatId, roomPassword);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'content': encryptedMessage,
        'room_id': roomKey,
        'username': "System",
        'user_id': "system_${DateTime.now().millisecondsSinceEpoch}",
        'created_at': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print("⚠️ Не удалось отправить системное сообщение: $e");
    }
  }

  // ==================== УДАЛЕНИЕ СООБЩЕНИЯ ====================
  
  /// Безопасное удаление сообщения с проверкой прав
  Future<void> deleteMessage(MessageModel message) async {
    try {
      // 1. Проверяем, может ли пользователь удалить это сообщение
      final String currentUserId = conf.userId;
      final String messageAuthorId = message.userId;
      
      bool canDelete = false;
      
      // Правило 1: Автор может удалить своё сообщение
      if (currentUserId == messageAuthorId) {
        canDelete = true;
        debugPrint("✅ Пользователь удаляет своё сообщение");
      }
      
      // Правило 2: Администратор может удалить любое сообщение
      if (currentUserId == _chatAdminId && _chatAdminId.isNotEmpty) {
        canDelete = true;
        debugPrint("✅ Администратор удаляет сообщение");
      }
      
      // 2. Если прав нет - показываем ошибку
      if (!canDelete) {
        debugPrint("❌ Нет прав для удаления этого сообщения!");
        throw Exception("Вы можете удалять только свои сообщения");
      }
      
      // 3. Если права есть - удаляем
      await _firebase.deleteFirebaseMessage(roomId, message.id);
      
      // 4. Удаляем из локального списка
      displayMsgs.removeWhere((msg) => msg.id == message.id);
      notifyListeners(); 
      
      // 5. Удаляем из локальной базы данных
      if (!kIsWeb) {
        await DBHelper.deleteMessage(message.id);
      }
      
      debugPrint("✅ Сообщение ${message.id} успешно удалено");
      
    } catch (e) {
      debugPrint("❌ Ошибка удаления: $e");
      rethrow;
    }
  }

/// Удаляет пользователя из чата (только для администратора)
Future<void> removeUserFromChat(String chatId, String userUid) async {
  try {
    // 1. Проверяем права администратора
    final currentUserId = conf.userId;
    
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      throw Exception("Чат не найден");
    }
    
    final chatData = chatDoc.data() as Map<String, dynamic>;
    final String? adminId = chatData['adminId'];
    
    if (adminId != currentUserId) {
      throw Exception("Только администратор может удалять участников");
    }
    
    // 2. Нельзя удалить самого себя (администратор не может выгнать сам себя)
    if (userUid == currentUserId) {
      throw Exception("Вы не можете удалить себя из чата. Используйте кнопку 'Выйти'");
    }
    
    // 3. Получаем список участников
    final List<dynamic> participants = chatData['participants'] ?? [];
    
    if (!participants.contains(userUid)) {
      throw Exception("Пользователь не состоит в этом чате");
    }
    
    // 4. Удаляем пользователя из чата
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayRemove([userUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // 5. Отправляем системное сообщение (опционально)
    await _sendKickMessage(chatId, userUid);
    
    print("✅ Пользователь $userUid удалён из чата");
    
  } catch (e) {
    print("❌ Ошибка удаления пользователя: $e");
    rethrow;
  }
}

/// Отправляет системное сообщение о том, что пользователь был удалён
Future<void> _sendKickMessage(String chatId, String kickedUserUid) async {
  try {
    final userProfile = await _firestore
        .collection('users_profiles')
        .doc(kickedUserUid)
        .get();
    
    String nickname = userProfile.data()?['nickname'] ?? 'Пользователь';
    
    final roomPassword = conf.roomPasswords[chatId] ?? "";
    final encryptedMessage = EncryptionService.encrypt(
      "🚫 $nickname был удалён из чата администратором", 
      roomPassword, 
      chatId
    );
    
    final roomKey = conf.hashRoomKey(chatId, roomPassword);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'content': encryptedMessage,
      'room_id': roomKey,
      'username': "System",
      'user_id': "system_${DateTime.now().millisecondsSinceEpoch}",
      'created_at': FieldValue.serverTimestamp(),
      'is_system': true,
    });
    
  } catch (e) {
    print("⚠️ Ошибка системного сообщения: $e");
  }
}



  // ==================== ОТПРАВКА СООБЩЕНИЯ ====================
  
// В chat_viewmodel.dart, в методе sendMessage:

Future<void> sendMessage(String text) async {
  if (text.trim().isEmpty) return;

  final String roomPassword = conf.roomPasswords[roomId] ?? "";
  
  try {
    // Отправляем через оффлайн-сервис
    await _syncService.sendMessageOffline(
      roomId: roomId,
      content: text,
      username: conf.nickname,
      userId: conf.userId,
      roomPassword: roomPassword,
    );
    
    // Уведомления отправляем только если онлайн
    if (await _syncService.isOnline) {
      final chatTitle = await _getChatTitle();
      await _fcmSender.sendToChatParticipants(
        chatId: roomId,
        senderId: conf.userId,
        senderName: conf.nickname,
        messageText: text,
        chatTitle: chatTitle,
      );
    }
    
  } catch (e) {
    debugPrint("Ошибка отправки: $e");
  }
}

// Добавьте вспомогательный метод для получения названия чата
Future<String> _getChatTitle() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(roomId)
        .get();
    return doc.data()?['title'] ?? 'Чат';
  } catch (e) {
    return 'Чат';
  }
}

  // ==================== СИГНАЛ ЗВОНКА ====================
  
  Future<void> sendCallSignal(String callId) async {
    final messageData = {
      'id': 'call_${DateTime.now().millisecondsSinceEpoch}',
      'room_id': roomId,
      'content': 'INCOMING_VIDEO_CALL:$callId', 
      'username': conf.nickname,
      'user_id': conf.userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _firebase.sendMessage(messageData);
  }

  // ==================== ЖАЛОБЫ ====================
  
  Future<void> reportMessage(MessageModel message, String reason) async {
    try {
      await _firebase.reportContent(
        reportedUserId: message.userId,
        messageId: message.id,
        roomId: roomId,
        reason: reason,
      );
    } catch (e) {
      debugPrint("Ошибка жалобы: $e");
    }
  }

  // ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================
  
  // Получение реального ника из Firestore с кэшированием
  Future<String> _getVerifiedNickname(String uid, String fallbackNick) async {
    if (_userNicknamesCache.containsKey(uid)) {
      return _userNicknamesCache[uid]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users_profiles')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        String nick = doc.data()!['nickname'] ?? fallbackNick;
        _userNicknamesCache[uid] = nick;
        return nick;
      }
    } catch (e) {
      debugPrint("Ошибка получения ника для $uid: $e");
    }

    return fallbackNick;
  }

  // Геттер: является ли пользователь администратором
  bool get isAdmin => conf.userId == _chatAdminId;

  // Очистка ресурсов при закрытии
  @override
  void dispose() {
    _sub?.cancel();
    _userNicknamesCache.clear();
    super.dispose();
  }
}