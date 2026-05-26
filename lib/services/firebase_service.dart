import 'package:chat/models/chat_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import 'dart:developer' as dev;
import 'account_deletion_service.dart'; // Добавьте импорт

class FirebaseService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;


final FirebaseFirestore _db = FirebaseFirestore.instance;

Stream<QuerySnapshot> getChatsStream(String uid) {
    // Получаем чаты, где текущий пользователь есть в списке участников
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }


// Future<void> sendReport({required String targetId, required String reason}) async {
//   try {
//     await _db.collection('reports').add({
//       'reporterId': _auth.currentUser?.uid, // Кто жалуется
//       'targetId': targetId,                 // На кого жалуется
//       'reason': reason,                     // Причина
//       'timestamp': FieldValue.serverTimestamp(),
//       'status': 'pending',                  // Статус для админки
//     });
//     print("✅ Жалоба отправлена");
//   } catch (e) {
//     print("❌ Ошибка при отправке жалобы: $e");
//     rethrow;
//   }
// }






// Внутри класса FirebaseService
Future<String> createChat(ChatModel chat) async {
  final docRef = await FirebaseFirestore.instance
      .collection('chats')
      .add(chat.toMap());
  return docRef.id;
}




// lib/services/firebase_service.dart

// Добавьте в класс FirebaseService:
Stream<QuerySnapshot> getSupportMessages() {
  // Для админа — все сообщения, для юзера — только его
  if (_auth.currentUser?.email == 'anvistanb17@gmail.com') {
    return _firestore.collection('support_tickets').orderBy('timestamp', descending: true).snapshots();
  } else {
    return _firestore.collection('support_tickets')
        .where('userId', isEqualTo: _auth.currentUser?.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

Future<void> sendSupportMessage(String text, String nickname) async {
  final user = _auth.currentUser;
  if (user == null) return;

  await _firestore.collection('support_tickets').add({
    'userId': user.uid,
    'userEmail': user.email,
    'nickname': nickname,
    'message': text,
    'timestamp': FieldValue.serverTimestamp(),
    'isAdmin': user.email == 'anvistanb17@gmail.com',
  });
}











Future<void> sendReport(String targetUserId, String reason) async {
  try {
    await _db.collection('reports').add({
      'reporterId': _auth.currentUser?.uid,
      'targetId': targetUserId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    print("✅ Жалоба отправлена");
  } catch (e) {
    print("❌ Ошибка при отправке жалобы: $e");
    rethrow;
  }
}









// firebase_service.dart
Future<void> deleteFirebaseMessage(String roomId, String messageId) async {
  try {
    await _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .delete();
    print("✅ Сообщение удалено из Firebase");
  } catch (e) {
    print("❌ Ошибка при удалении из Firebase: $e");
    rethrow;
  }
}





Future<void> sendPasswordReset(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
    dev.log('Письмо для сброса пароля отправлено на $email');
  } catch (e) {
    dev.log('Ошибка сброса пароля: $e');
    rethrow;
  }
}





Future<void> reportContent({
  required String reportedUserId,
  required String messageId,
  required String reason,
  required String roomId,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  try {
    await _firestore.collection('reports').add({
      'reporter_id': user.uid,
      'reported_user_id': reportedUserId,
      'message_id': messageId,
      'room_id': roomId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending', // Для админ-панели
    });
  } catch (e) {
    dev.log('Ошибка при отправке жалобы: $e');
    rethrow;
  }
}




















  User? get currentUser => _auth.currentUser;

  // Стрим для отслеживания данных профиля (включая isVerified)
  Stream<DocumentSnapshot> getUserProfileStream(String uid) {
    return _firestore.collection('users_profiles').doc(uid).snapshots();
  }

  // --- Сообщения ---

  Stream<List<MessageModel>> getMessagesStream(String rKey) {
    return _firestore
        .collection('rooms')
        .doc(rKey)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> sendMessage(Map<String, dynamic> data) async {
    final rKey = data['room_id'];
    final user = _auth.currentUser;
    if (rKey == null || user == null) return;

    try {
      await _firestore
          .collection('rooms')
          .doc(rKey)
          .collection('messages')
          .add({
        'content': data['content'],
        'room_id': rKey,
        'username': data['username'] ?? 'Anonymous',
        'user_id': user.uid,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('Ошибка при отправке: $e');
      rethrow;
    }
  }


























  // --- Авторизация ---

// Внутри класса FirebaseService

// 1. Обновляем регистрацию
Future<UserCredential?> registerWithEmail(String email, String password, String nickname) async {
  try {
    UserCredential res = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    
    // Сразу шлем письмо
    await res.user?.sendEmailVerification();
    await res.user?.updateDisplayName(nickname);

    await syncProfile(res.user!.uid, {
      'nickname': nickname, 
      'email': email,
      'isVerified': true, 
      'created_at': FieldValue.serverTimestamp(),
    });
    
    return res;
  } on FirebaseAuthException catch (_) {
    // Если такая почта уже есть, мы пробрасываем ошибку дальше, 
    // чтобы ViewModel её обработала и предложила вход.
    rethrow;
  }
}

// 2. Добавляем метод для повторной отправки
Future<void> sendVerificationEmail() async {
  final user = _auth.currentUser;
  if (user != null && !user.emailVerified) {
    await user.sendEmailVerification();
    print("✅ Письмо отправлено повторно на ${user.email}");
  }
}

// 3. Метод для обновления данных (проверки, нажал ли он ссылку)
Future<void> reloadUser() async {
  await _auth.currentUser?.reload();
}

Future<UserCredential?> loginWithEmail(String email, String password) async {
  return await _auth.signInWithEmailAndPassword(
    email: email.trim(), // Защита от случайного пробела
    password: password
  );
}

  Future<void> signOut() async => await _auth.signOut();

  Future<void> syncProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users_profiles').doc(uid).set(data, SetOptions(merge: true));
  }









/// Проверяет, свободен ли никнейм
Future<bool> isNicknameAvailable(String nickname) async {
  try {
    final querySnapshot = await _firestore
        .collection('users_profiles')
        .where('nickname', isEqualTo: nickname.trim())
        .limit(1)
        .get();
    
    return querySnapshot.docs.isEmpty;
  } catch (e) {
    debugPrint("Ошибка проверки ника: $e");
    return false;
  }
}

/// Обновляет никнейм с проверкой уникальности
Future<void> updateNicknameWithCheck(String uid, String newNickname) async {
  // Проверяем, не занят ли ник
  final isAvailable = await isNicknameAvailable(newNickname);
  if (!isAvailable) {
    throw Exception("Никнейм '$newNickname' уже занят. Выберите другой.");
  }
  
  // Проверяем длину
  if (newNickname.length < 3 || newNickname.length > 20) {
    throw Exception("Никнейм должен быть от 3 до 20 символов");
  }
  
  // Проверяем допустимые символы
  final regex = RegExp(r'^[a-zA-Z0-9а-яА-Я_]+$');
  if (!regex.hasMatch(newNickname)) {
    throw Exception("Никнейм может содержать только буквы, цифры и знак подчёркивания");
  }
  
  // Обновляем
  await _firestore.collection('users_profiles').doc(uid).update({
    'nickname': newNickname.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}











Future<void> deleteAccount() async {
  final user = _auth.currentUser;
  if (user == null) return;
  
  try {
    // Запрашиваем свежие данные пользователя
    await user.reload();
    final freshUser = _auth.currentUser;
    
    // Если прошло слишком много времени с последнего входа
    if (freshUser?.metadata.lastSignInTime != null &&
        DateTime.now().difference(freshUser!.metadata.lastSignInTime!) > const Duration(minutes: 5)) {
      throw Exception("Для безопасности подтвердите вход заново");
    }
    
    final uid = user.uid;
    
    // 1. ПОЛНОЕ УДАЛЕНИЕ ВСЕХ ДАННЫХ
    final deletionService = AccountDeletionService();
    await deletionService.deleteAllUserData(uid);
    
    // 2. Проверяем, что данные действительно удалены
    final remainingData = await deletionService.checkRemainingData(uid);
    debugPrint("📊 Остаточные данные: $remainingData");
    
    // 3. Удаляем аккаунт из Firebase Auth
    await user.delete();
    
    debugPrint("✅ Аккаунт и все данные полностью удалены");
    
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      throw Exception("Пожалуйста, выйдите и зайдите снова перед удалением аккаунта");
    }
    debugPrint("❌ Ошибка при удалении: ${e.message}");
    rethrow;
  } catch (e) {
    debugPrint("❌ Неожиданная ошибка: $e");
    rethrow;
  }
}
}