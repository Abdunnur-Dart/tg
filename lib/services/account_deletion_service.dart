import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AccountDeletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Полное удаление всех данных пользователя
  Future<void> deleteAllUserData(String uid) async {
    debugPrint("🚀 Начинаем полное удаление данных пользователя: $uid");
    
    try {
      // 1. Удаляем все сообщения пользователя
      await _deleteAllUserMessages(uid);
      
      // 2. Удаляем пользователя из всех чатов
      await _removeUserFromAllChats(uid);
      
      // 3. Удаляем все звонки пользователя
      await _deleteAllUserCalls(uid);
      
      // 4. Удаляем все жалобы от пользователя и на пользователя
      await _deleteAllReports(uid);
      
      // 5. Удаляем все блокировки
      await _deleteAllBlocks(uid);
      
      // 6. Удаляем профиль пользователя
      await _deleteUserProfile(uid);
      
      // 7. Удаляем тикеты поддержки
      await _deleteSupportTickets(uid);
      
      debugPrint("✅ Все данные пользователя удалены успешно");
      
    } catch (e) {
      debugPrint("❌ Ошибка при удалении данных: $e");
      rethrow;
    }
  }

  /// 1. Удаление всех сообщений пользователя
  Future<void> _deleteAllUserMessages(String uid) async {
    debugPrint("📝 Удаляем сообщения пользователя...");
    
    // Ищем все чаты, где есть сообщения пользователя
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
    
    int totalDeleted = 0;
    
    for (var chatDoc in chatsSnapshot.docs) {
      final chatId = chatDoc.id;
      
      // Получаем сообщения пользователя в этом чате
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('user_id', isEqualTo: uid)
          .get();
      
      if (messagesSnapshot.docs.isNotEmpty) {
        // Удаляем batch'ами по 500 сообщений
        for (int i = 0; i < messagesSnapshot.docs.length; i += 500) {
          final batch = _firestore.batch();
          final end = (i + 500 < messagesSnapshot.docs.length) ? i + 500 : messagesSnapshot.docs.length;
          
          for (int j = i; j < end; j++) {
            batch.delete(messagesSnapshot.docs[j].reference);
          }
          
          await batch.commit();
          totalDeleted += (end - i);
          debugPrint("   Удалено $totalDeleted сообщений...");
        }
      }
    }
    
    debugPrint("   ✅ Удалено $totalDeleted сообщений");
  }

  /// 2. Удаляем пользователя из всех чатов
  Future<void> _removeUserFromAllChats(String uid) async {
    debugPrint("👥 Удаляем пользователя из чатов...");
    
    final chatsSnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
    
    int chatsUpdated = 0;
    
    for (var chatDoc in chatsSnapshot.docs) {
      await chatDoc.reference.update({
        'participants': FieldValue.arrayRemove([uid])
      });
      chatsUpdated++;
    }
    
    debugPrint("   ✅ Обновлено $chatsUpdated чатов");
  }

  /// 3. Удаление звонков пользователя
  Future<void> _deleteAllUserCalls(String uid) async {
    debugPrint("📞 Удаляем звонки пользователя...");
    
    // Звонки, где пользователь участник
    final callsAsParticipant = await _firestore
        .collection('calls')
        .where('participants', arrayContains: uid)
        .get();
    
    // Звонки, где пользователь инициатор
    final callsAsCaller = await _firestore
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .get();
    
    final allCalls = {...callsAsParticipant.docs, ...callsAsCaller.docs};
    
    int callsDeleted = 0;
    
    // Удаляем batch'ами
    final List<DocumentReference> toDelete = [];
    for (var callDoc in allCalls) {
      toDelete.add(callDoc.reference);
    }
    
    for (int i = 0; i < toDelete.length; i += 500) {
      final batch = _firestore.batch();
      final end = (i + 500 < toDelete.length) ? i + 500 : toDelete.length;
      
      for (int j = i; j < end; j++) {
        batch.delete(toDelete[j]);
      }
      
      await batch.commit();
      callsDeleted += (end - i);
    }
    
    debugPrint("   ✅ Удалено $callsDeleted звонков");
  }

  /// 4. Удаление всех жалоб
  Future<void> _deleteAllReports(String uid) async {
    debugPrint("⚠️ Удаляем жалобы...");
    
    // Жалобы, отправленные пользователем
    final reportsByUser = await _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: uid)
        .get();
    
    // Жалобы на пользователя
    final reportsOnUser = await _firestore
        .collection('reports')
        .where('targetId', isEqualTo: uid)
        .get();
    
    final allReports = {...reportsByUser.docs, ...reportsOnUser.docs};
    
    int reportsDeleted = 0;
    final batch = _firestore.batch();
    
    for (var reportDoc in allReports) {
      batch.delete(reportDoc.reference);
      reportsDeleted++;
    }
    
    await batch.commit();
    debugPrint("   ✅ Удалено $reportsDeleted жалоб");
  }

  /// 5. Удаление блокировок
  Future<void> _deleteAllBlocks(String uid) async {
    debugPrint("🔒 Удаляем блокировки...");
    
    // Блокировки, установленные пользователем
    final blocksByUser = await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .get();
    
    int blocksDeleted = 0;
    
    for (var blockDoc in blocksByUser.docs) {
      await blockDoc.reference.delete();
      blocksDeleted++;
    }
    
    // Также нужно удалить пользователя из блокировок других пользователей
    // Ищем всех, кто заблокировал этого пользователя
    final usersSnapshot = await _firestore.collection('users').get();
    int unblocksCount = 0;
    
    for (var userDoc in usersSnapshot.docs) {
      final blockedRef = _firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('blocked')
          .doc(uid);
      
      final blockedDoc = await blockedRef.get();
      if (blockedDoc.exists) {
        await blockedRef.delete();
        unblocksCount++;
      }
    }
    
    debugPrint("   ✅ Удалено $blocksDeleted блокировок (и разблокировано из $unblocksCount)");
  }

  /// 6. Удаление профиля
  Future<void> _deleteUserProfile(String uid) async {
    debugPrint("👤 Удаляем профиль...");
    
    final profileRef = _firestore.collection('users_profiles').doc(uid);
    final profileDoc = await profileRef.get();
    
    if (profileDoc.exists) {
      await profileRef.delete();
      debugPrint("   ✅ Профиль удалён");
    } else {
      debugPrint("   ⚠️ Профиль не найден");
    }
  }

  /// 7. Удаление тикетов поддержки
  Future<void> _deleteSupportTickets(String uid) async {
    debugPrint("🎫 Удаляем обращения в поддержку...");
    
    final ticketsRef = _firestore.collection('support_tickets').doc(uid);
    final ticketsDoc = await ticketsRef.get();
    
    if (ticketsDoc.exists) {
      // Удаляем все сообщения в тикете
      final messagesSnapshot = await ticketsRef
          .collection('messages')
          .get();
      
      final batch = _firestore.batch();
      for (var msgDoc in messagesSnapshot.docs) {
        batch.delete(msgDoc.reference);
      }
      await batch.commit();
      
      // Удаляем сам тикет
      await ticketsRef.delete();
      debugPrint("   ✅ Тикет поддержки удалён");
    } else {
      debugPrint("   ⚠️ Тикетов поддержки не найдено");
    }
  }

/// Вспомогательный метод: проверка, сколько данных осталось
Future<Map<String, int>> checkRemainingData(String uid) async {
  debugPrint("🔍 Проверяем остаточные данные...");
  
  final messagesQuery = await _firestore
      .collectionGroup('messages')
      .where('user_id', isEqualTo: uid)
      .count()
      .get();
  
  final chatsQuery = await _firestore
      .collection('chats')
      .where('participants', arrayContains: uid)
      .count()
      .get();
  
  final callsQuery = await _firestore
      .collection('calls')
      .where('participants', arrayContains: uid)
      .count()
      .get();
  
  final reportsQuery = await _firestore
      .collection('reports')
      .where('reporterId', isEqualTo: uid)
      .count()
      .get();
  
  return {
    'messages': messagesQuery.count ?? 0,
    'chats': chatsQuery.count ?? 0,
    'calls': callsQuery.count ?? 0,
    'reports': reportsQuery.count ?? 0,
  };
}
}