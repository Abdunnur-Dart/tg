// lib/services/block_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Заблокировать пользователя
  Future<void> blockUser(String targetUserId, {String? reason}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Не авторизован");
    if (targetUserId == currentUser.uid) {
      throw Exception("Нельзя заблокировать себя");
    }
    
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(targetUserId)
        .set({
      'userId': targetUserId,
      'blockedBy': currentUser.uid,
      'blockedAt': FieldValue.serverTimestamp(),
      'reason': reason,
    });
  }
  
  // Разблокировать пользователя
  Future<void> unblockUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(targetUserId)
        .delete();
  }
  
  // Проверить, заблокирован ли пользователь
  Future<bool> isBlocked(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    
    final doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(targetUserId)
        .get();
    
    return doc.exists;
  }
  
  // ПОЛУЧИТЬ СТРИМ ЗАБЛОКИРОВАННЫХ ПОЛЬЗОВАТЕЛЕЙ (ДОБАВЛЕНО)
  Stream<List<BlockedUser>> getBlockedUsersStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();
    
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return BlockedUser(
            userId: data['userId'] ?? '',
            blockedBy: data['blockedBy'] ?? '',
            blockedAt: (data['blockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            reason: data['reason'],
          );
        }).toList());
  }
}

// Модель заблокированного пользователя (если нет отдельного файла)
class BlockedUser {
  final String userId;
  final String blockedBy;
  final DateTime blockedAt;
  final String? reason;
  
  BlockedUser({
    required this.userId,
    required this.blockedBy,
    required this.blockedAt,
    this.reason,
  });
}