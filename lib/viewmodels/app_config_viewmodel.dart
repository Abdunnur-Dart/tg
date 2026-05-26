import 'dart:convert';
import 'package:chat/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import '../services/db_helper.dart';
import '../services/encryption_service.dart';
import '../services/secure_storage_service.dart';

class AppConfigViewModel with ChangeNotifier {

  final _firebase = FirebaseService();
// Исправленная строка 16 (внутри класса AppConfigViewModel)


  // --- Состояние пользователя ---
  String userId = "";
  String nickname = "User";
  bool isOnline = true;
  bool isManualVerified = false;

  String get userEmail => _firebase.currentUser?.email ?? "";
  bool get isEmailVerified => _firebase.currentUser?.emailVerified ?? false;
  // --- Состояние пользователя ---
 







// TODO: Вынести Google Sign-In в отдельный сервис, но пока так для простоты




















// Добавьте в класс AppConfigViewModel
Future<void> deleteAccountWithProgress(Function(int step, int total, String message) onProgress) async {
  try {
    onProgress(1, 7, "Удаляем сообщения...");
    // Здесь можно вызвать удаление с колбэками
    await _firebase.deleteAccount();
    await logout();
  } catch (e) {
    debugPrint("Error: $e");
    rethrow;
  }
}











// В файле viewmodels/app_config_viewmodel.dart






















// В файл app_config_viewmodel.dart

// Добавь это внутрь класса AppConfigViewModel
Future<void> updateNickname(String newNick) async {
  if (newNick.trim().isEmpty) {
    throw Exception("Никнейм не может быть пустым");
  }
  
  // Проверяем через сервис
  final isAvailable = await _firebase.isNicknameAvailable(newNick);
  if (!isAvailable) {
    throw Exception("Никнейм уже занят");
  }
  
  await _firebase.updateNicknameWithCheck(userId, newNick);
  
  nickname = newNick.trim();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_nickname', nickname);
  notifyListeners();
}










// Внутри класса AppConfigViewModel
Future<void> resetPassword(String email) async {
  if (email.isEmpty) throw "Введите email";
  await _firebase.sendPasswordReset(email);
}






Future<void> clearLocalCache() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Полностью очищаем все локальные сохранения (тема, пин-код, кэш)[cite: 12]
  await prefs.clear(); 
  
  // Очищаем переменные в текущей сессии
  pinCode = null;
  nickname = "User"; // Значение по умолчанию
  
  notifyListeners(); 
  print("Локальный кэш полностью очищен");
}





  


  // --- Настройки интерфейса ---
  double fontSize = 16.0;
  double bubbleRadius = 18.0;
  double bubbleOpacity = 0.9;
  ThemeMode themeMode = ThemeMode.dark;
  Color accentColor = Colors.blueAccent;
  
  int bgIndex = 0;
  final List<List<Color>> backgrounds = [
    [Colors.blueGrey.shade900, Colors.black],
    [Colors.indigo.shade900, Colors.black],
    [Colors.deepPurple.shade900, Colors.black],
  ];

  // --- Безопасность ---
  String? pinCode;
  Map<String, String> roomPasswords = {};

  AppConfigViewModel() {
    _load();
  }

Future<void> _load() async {
  final prefs = await SharedPreferences.getInstance();
  
  userId = prefs.getString('user_id') ?? "";
  nickname = prefs.getString('user_nickname') ?? "User";
  
  // ✨ НОВОЕ: Загружаем PIN из безопасного хранилища
  pinCode = await SecureStorageService.loadPinCode();
  
  // ✨ НОВОЕ: Загружаем пароли комнат из безопасного хранилища
  roomPasswords = await SecureStorageService.loadRoomPasswords();
  
  if (userId.isNotEmpty) {
    startVerificationListener(userId);
  }

  fontSize = prefs.getDouble('font_size') ?? 16.0;
  bubbleRadius = prefs.getDouble('bubble_radius') ?? 18.0;
  bgIndex = prefs.getInt('bg_index') ?? 0;
  accentColor = Color(prefs.getInt('accent_color') ?? Colors.blueAccent.value);
  
  final savedTheme = prefs.getString('theme_mode') ?? "dark";
  themeMode = savedTheme == "light" ? ThemeMode.light : ThemeMode.dark;

  notifyListeners();
}

  // Стриминг статуса верификации
  void startVerificationListener(String uid) {
    FirebaseFirestore.instance
        .collection('users_profiles')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        isManualVerified = doc.data()?['isVerified'] ?? false;
        notifyListeners(); 
      }
    });
  }

  // --- Управление настройками ---
  void setBgIndex(int index) async {
    bgIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bg_index', index);
    notifyListeners();
  }

  void setFontSize(double size) async {
    fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
    notifyListeners();
  }

  void setBubbleRadius(double radius) async {
    bubbleRadius = radius;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bubble_radius', radius);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? "light" : "dark");
    notifyListeners();
  }

  void setAccentColor(Color color) async {
    accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.value);
    notifyListeners();
  }

  // --- Аккаунт ---
// Находим метод authAction и заменяем его на этот:
Future<void> authAction(String email, String password, String nickname, bool isLogin) async {
  try {
    UserCredential? res;
    
    if (isLogin) {
      res = await _firebase.loginWithEmail(email, password);
    } else {
      try {
        res = await _firebase.registerWithEmail(email, password, nickname);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          res = await _firebase.loginWithEmail(email, password);
          await _firebase.sendVerificationEmail();
        } else {
          rethrow;
        }
      }
    }

    if (res?.user != null) {
      userId = res!.user!.uid;
      nickname = res.user!.displayName ?? nickname;
      
      // ⬇️⬇️⬇️ ВОТ ЭТИ 2 СТРОЧКИ УЖЕ ЕСТЬ? ⬇️⬇️⬇️
      await NotificationService.saveTokenToFirestore(userId);
      // ⬆️⬆️⬆️ ЭТО СОХРАНЯЕТ ТОКЕН В БАЗУ ДАННЫХ ⬆️⬆️⬆️
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_nickname', nickname);
      
      notifyListeners();
    }
  } catch (e) {
    debugPrint("Auth Error: $e");
    rethrow;
  }
}
// Future<void> authAction(String email, String password, String nickname, bool isLogin) async {
//   try {
//     UserCredential? res;
    
//     if (isLogin) {
//       // Вход существующего пользователя
//       res = await _firebase.loginWithEmail(email, password);
//     } else {
//       // Регистрация нового
//       try {
//         res = await _firebase.registerWithEmail(email, password, nickname);
//       } on FirebaseAuthException catch (e) {
//         // Если почта уже используется, пробуем войти
//         if (e.code == 'email-already-in-use') {
//           debugPrint("⚠️ Почта занята. Входим...");
//           res = await _firebase.loginWithEmail(email, password);
//           await _firebase.sendVerificationEmail();
//         } else {
//           rethrow;
//         }
//       }
//     }

//     // Если авторизация прошла успешно
//     if (res?.user != null) {
//       userId = res!.user!.uid;
//       nickname = res.user!.displayName ?? nickname;
      
//       // Сохраняем FCM токен
//       await NotificationService.saveTokenToFirestore(userId);
      
//       // Сохраняем данные локально
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('user_id', userId);
//       await prefs.setString('user_nickname', nickname);
      
//       notifyListeners();
//     }
//   } catch (e) {
//     debugPrint("Auth Error: $e");
//     rethrow;
//   }
// }

Future<void> logout() async {
  await DBHelper.clearAll();
  // ✨ НОВОЕ: Очищаем безопасное хранилище
  await SecureStorageService.clearAll();
    await NotificationService.deleteTokenFromFirestore(userId);
  
  // ... существующий код очистки ...
  
  await DBHelper.clearAll();
  await SecureStorageService.clearAll();
  
  userId = "";
  nickname = "User";
  roomPasswords = {};
  pinCode = null;
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  
  notifyListeners();
}

  Future<void> deleteAccount() async {
    try {
      await _firebase.deleteAccount();
      await logout(); 
    } catch (e) {
      debugPrint("Error: $e");
      rethrow;
    }
  }




// Внутри класса AppConfigViewModel

// Проверяем, подтверждена ли почта прямо сейчас
// TODO тут поставить это опять это нужно было чтоб избежать потдверждение емаил каждый раз убрать final _firebase = FirebaseService(); на строке 24 может сменится
//bool get isEmailVerified => _firebase.currentUser?.emailVerified ?? false;



// Метод для принудительного обновления статуса из Firebase
Future<void> checkEmailVerificationStatus() async {
  await _firebase.reloadUser();
  notifyListeners(); // Это заставит UI перестроиться
}

Future<void> resendVerification() async {
  await _firebase.sendVerificationEmail();
}



  // --- PIN и Комнаты ---
void setPinCode(String? code) async {
  pinCode = code;
  // ✨ НОВОЕ: Сохраняем в безопасное хранилище
  await SecureStorageService.savePinCode(code);
  notifyListeners();
}

void addRoom(String name, String password) async {
  if (name.isEmpty) return;
  roomPasswords[name] = password;
  // ✨ НОВОЕ: Сохраняем в безопасное хранилище
  await SecureStorageService.saveRoomPassword(name, password);
  notifyListeners();
}


  void removeRoom(String name) async {
    roomPasswords.remove(name);
    await DBHelper.clearRoom(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_passwords', json.encode(roomPasswords));
    notifyListeners();
  }

  String hashRoomKey(String name, String pass) {
    return EncryptionService.hashPin(name + pass, "global_salt_v31");
  }
}