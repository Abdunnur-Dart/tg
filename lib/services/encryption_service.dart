// // // // import 'dart:convert';
// // // // import 'dart:typed_data';
// // // // import 'package:crypto/crypto.dart' as crypto;
// // // // import 'package:pointycastle/export.dart';
// // // // import 'package:encrypt/encrypt.dart' as enc;
// // // // import 'package:flutter/foundation.dart';

// // // // class EncryptionService {
// // // //   // 1. Деривация ключа (PBKDF2)
// // // //   // Превращает обычный пароль в надежный 32-байтный ключ для AES
// // // //   static enc.Key _deriveKey(String password, String salt) {
// // // //     if (password.isEmpty) {
// // // //       // Чтобы не падать, если пароль пустой, создаем "пустой" ключ 
// // // //       // (хотя до этого доходить не должно из-за проверок ниже)
// // // //       return enc.Key(Uint8List(32));
// // // //     }

// // // //     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
// // // //     pkcs.init(Pbkdf2Parameters(
// // // //       utf8.encode(salt), 
// // // //       100000, // Количество итераций (чем больше, тем сложнее взломать)
// // // //       32      // Длина ключа в байтах (256 бит)
// // // //     ));
// // // //     return enc.Key(pkcs.process(utf8.encode(password)));
// // // //   }

// // // //   // 2. Деривация ключа комнаты (для Firestore ключей)
// // // //   static String deriveRoomKey(String password, String salt) {
// // // //     if (password.isEmpty) return "default_room_key";
    
// // // //     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
// // // //     pkcs.init(Pbkdf2Parameters(utf8.encode(salt), 50000, 32));
// // // //     final keyBytes = pkcs.process(utf8.encode(password));
// // // //     return base64Url.encode(keyBytes);
// // // //   }

// // // //   // 3. Хеширование PIN-кода (усиленное)
// // // //   static String hashPin(String pin, String salt) {
// // // //     if (pin.isEmpty) return "";
// // // //     try {
// // // //       // Используем PBKDF2 для хеширования PIN, чтобы его нельзя было подобрать перебором
// // // //       final key = _deriveKey(pin, "pin_salt_$salt");
// // // //       return key.base64;
// // // //     } catch (e) {
// // // //       debugPrint("Ошибка хеширования PIN: $e");
// // // //       // Резервный вариант на случай ошибки библиотеки
// // // //       final bytes = utf8.encode(pin + salt);
// // // //       return crypto.sha256.convert(bytes).toString();
// // // //     }
// // // //   }

// // // //   // 4. Шифрование AES-GCM
// // // //   static String encrypt(String text, String password, String roomId) {
// // // //     // ЗАЩИТА: Если пароль или текст пустые, возвращаем оригинал, чтобы избежать ошибки
// // // //     if (password.isEmpty || text.isEmpty) {
// // // //       debugPrint("Encryption Warning: Password or text is empty.");
// // // //       return text;
// // // //     }

// // // //     try {
// // // //       final key = _deriveKey(password, roomId);
// // // //       // Генерируем случайный IV (Initialization Vector) для каждой отправки
// // // //       final iv = enc.IV.fromSecureRandom(12); // Для GCM рекомендуется 12 байт
      
// // // //       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
// // // //       final encrypted = encrypter.encrypt(text, iv: iv);
      
// // // //       // Склеиваем IV и зашифрованные данные через двоеточие
// // // //       return "${iv.base64}:${encrypted.base64}";
// // // //     } catch (e) {
// // // //       debugPrint("Encryption Error: $e");
// // // //       return text;
// // // //     }
// // // //   }

// // // //   // 5. Расшифровка AES-GCM
// // // //   static String decrypt(String combinedData, String password, String roomId) {
// // // //     // Если пароль пустой или данные не содержат разделитель IV, не пытаемся расшифровать
// // // //     if (password.isEmpty || !combinedData.contains(':')) return combinedData;

// // // //     try {
// // // //       final parts = combinedData.split(':');
// // // //       if (parts.length < 2) return combinedData;

// // // //       final iv = enc.IV.fromBase64(parts[0]);
// // // //       final encryptedContent = parts[1];

// // // //       final key = _deriveKey(password, roomId);
// // // //       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      
// // // //       return encrypter.decrypt(enc.Encrypted.fromBase64(encryptedContent), iv: iv);
// // // //     } catch (e) {
// // // //       debugPrint("Decryption Error (возможно неверный пароль): $e");
// // // //       return "[Ошибка расшифровки / Неверный ключ]";
// // // //     }
// // // //   }
// // // // }





// // // import 'dart:convert';
// // // import 'dart:typed_data';
// // // import 'package:crypto/crypto.dart' as crypto;
// // // import 'package:pointycastle/export.dart';
// // // import 'package:encrypt/encrypt.dart' as enc;
// // // import 'package:flutter/foundation.dart';

// // // class EncryptionService {
// // //   // Внутренний метод для генерации ключа
// // //   static enc.Key _deriveKey(String password, String salt) {
// // //     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
// // //     pkcs.init(Pbkdf2Parameters(
// // //       utf8.encode(salt), 
// // //       100000, 
// // //       32
// // //     ));
// // //     return enc.Key(pkcs.process(utf8.encode(password)));
// // //   }

// // //   // ТОТ САМЫЙ МЕТОД ДЛЯ PIN-КОДА
// // //   static String hashPin(String pin, String salt) {
// // //     if (pin.isEmpty) return "";
// // //     try {
// // //       // Используем ту же логику деривации для надежности
// // //       final key = _deriveKey(pin, "pin_salt_$salt");
// // //       return key.base64;
// // //     } catch (e) {
// // //       debugPrint("Ошибка хеширования PIN: $e");
// // //       final bytes = utf8.encode(pin + salt);
// // //       return crypto.sha256.convert(bytes).toString();
// // //     }
// // //   }

// // //   // Для шифрования сообщений
// // //   static String encrypt(String text, String password, String roomId) {
// // //     if (password.isEmpty || text.isEmpty) return text;
// // //     try {
// // //       final key = _deriveKey(password, roomId);
// // //       final iv = enc.IV.fromSecureRandom(12); 
// // //       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
// // //       final encrypted = encrypter.encrypt(text, iv: iv);
// // //       return "${iv.base64}:${encrypted.base64}";
// // //     } catch (e) {
// // //       return text;
// // //     }
// // //   }

// // //   // Для расшифровки сообщений
// // //   static String decrypt(String combinedData, String password, String roomId) {
// // //     if (password.isEmpty || !combinedData.contains(':')) return combinedData;
// // //     try {
// // //       final parts = combinedData.split(':');
// // //       final iv = enc.IV.fromBase64(parts[0]);
// // //       final encryptedContent = parts[1];
// // //       final key = _deriveKey(password, roomId);
// // //       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
// // //       return encrypter.decrypt(enc.Encrypted.fromBase64(encryptedContent), iv: iv);
// // //     } catch (e) {
// // //       return "[Ошибка расшифровки]";
// // //     }
// // //   }

// // //   // Для генерации ключа комнаты в Firestore
// // //   static String deriveRoomKey(String password, String salt) {
// // //     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
// // //     pkcs.init(Pbkdf2Parameters(utf8.encode(salt), 50000, 32));
// // //     return base64Url.encode(pkcs.process(utf8.encode(password)));
// // //   }
// // // }






















// // import 'dart:convert';
// // import 'dart:typed_data';
// // import 'package:crypto/crypto.dart' as crypto;
// // import 'package:pointycastle/export.dart';
// // import 'package:encrypt/encrypt.dart' as enc;
// // import 'package:flutter/foundation.dart';

// // class EncryptionService {
// //   // Внутренний метод (не удаляйте!)
// //   static enc.Key _deriveKey(String password, String salt) {
// //     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
// //     pkcs.init(Pbkdf2Parameters(utf8.encode(salt), 100000, 32));
// //     return enc.Key(pkcs.process(utf8.encode(password)));
// //   }

// //   // ОБЯЗАТЕЛЬНО: static и правильное имя hashPin
// //   static String hashPin(String pin, String salt) {
// //     if (pin.isEmpty) return "";
// //     try {
// //       final key = _deriveKey(pin, "pin_salt_$salt");
// //       return key.base64;
// //     } catch (e) {
// //       debugPrint("Ошибка хеширования PIN: $e");
// //       final bytes = utf8.encode(pin + salt);
// //       return crypto.sha256.convert(bytes).toString();
// //     }
// //   }

// //   // Методы для шифрования сообщений (проверьте наличие)
// //   static String encrypt(String text, String password, String roomId) {
// //     if (password.isEmpty || text.isEmpty) return text;
// //     try {
// //       final key = _deriveKey(password, roomId);
// //       final iv = enc.IV.fromSecureRandom(12);
// //       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
// //       return "${iv.base64}:${encrypter.encrypt(text, iv: iv).base64}";
// //     } catch (e) { return text; }
// //   }

// //   static String decrypt(String combinedData, String password, String roomId) {
// //     if (password.isEmpty || !combinedData.contains(':')) return combinedData;
// //     try {
// //       final parts = combinedData.split(':');
// //       final iv = enc.IV.fromBase64(parts[0]);
// //       final key = _deriveKey(password, roomId);
// //       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
// //       return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
// //     } catch (e) { return "[Ошибка расшифровки]"; }
// //   }
// // }


















// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:crypto/crypto.dart' as crypto;
// import 'package:pointycastle/export.dart';
// import 'package:encrypt/encrypt.dart' as enc;
// import 'package:flutter/foundation.dart';

// class EncryptionService {
//   // 1. Внутренний метод деривации ключа (PBKDF2)
//   static enc.Key _deriveKey(String password, String salt) {
//     if (password.isEmpty) return enc.Key(Uint8List(32));
    
//     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
//     pkcs.init(Pbkdf2Parameters(
//       utf8.encode(salt), 
//       100000, 
//       32
//     ));
//     return enc.Key(pkcs.process(utf8.encode(password)));
//   }

//   // 2. ТОТ САМЫЙ МЕТОД ДЛЯ КЛЮЧА КОМНАТЫ (исправляет вашу ошибку)
//   static String deriveRoomKey(String password, String salt) {
//     if (password.isEmpty) return "default_room_key";
    
//     final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
//     pkcs.init(Pbkdf2Parameters(utf8.encode(salt), 50000, 32));
//     final keyBytes = pkcs.process(utf8.encode(password));
//     // Используем base64Url, чтобы в ключе не было символов '/', которые ломают пути в Firebase
//     return base64Url.encode(keyBytes);
//   }

//   // 3. Хеширование PIN-кода
//   static String hashPin(String pin, String salt) {
//     if (pin.isEmpty) return "";
//     try {
//       final key = _deriveKey(pin, "pin_salt_$salt");
//       return key.base64;
//     } catch (e) {
//       final bytes = utf8.encode(pin + salt);
//       return crypto.sha256.convert(bytes).toString();
//     }
//   }

//   // 4. Шифрование сообщений (AES-GCM)
//   static String encrypt(String text, String password, String roomId) {
//     if (password.isEmpty || text.isEmpty) return text;
//     try {
//       final key = _deriveKey(password, roomId);
//       final iv = enc.IV.fromSecureRandom(12); 
//       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
//       final encrypted = encrypter.encrypt(text, iv: iv);
//       return "${iv.base64}:${encrypted.base64}";
//     } catch (e) {
//       return text;
//     }
//   }

//   // 5. Расшифровка сообщений (AES-GCM)
//   static String decrypt(String combinedData, String password, String roomId) {
//     if (password.isEmpty || !combinedData.contains(':')) return combinedData;
//     try {
//       final parts = combinedData.split(':');
//       final iv = enc.IV.fromBase64(parts[0]);
//       final encryptedContent = parts[1];
//       final key = _deriveKey(password, roomId);
//       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
//       return encrypter.decrypt(enc.Encrypted.fromBase64(encryptedContent), iv: iv);
//     } catch (e) {
//       return "[Ошибка расшифровки]";
//     }
//   }
// }

























import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

class EncryptionService {
  // Кэш для ключей комнат
  static final Map<String, enc.Key> _roomKeyCache = {};
  
  // Параметры для разных сценариев
  static const int _iterationsForPin = 50000;     // PIN-код
  static const int _iterationsForMessages = 2000; // Сообщения (быстро)
  static const int _iterationsForRoomKey = 10000; // Ключ комнаты
  
  // --- ДЛЯ ПИН-КОДА (одноразово, можно 50 000) ---
  static String hashPin(String pin, String salt) {
    if (pin.isEmpty) return "";
    try {
      final key = _deriveKey(pin, "pin_salt_$salt", _iterationsForPin);
      return base64Url.encode(key.bytes).replaceAll('=', '');
    } catch (e) {
      final bytes = utf8.encode(pin + salt);
      return crypto.sha256.convert(bytes).toString();
    }
  }
  
  // --- ДЛЯ СООБЩЕНИЙ (с кэшированием) ---
  static String encrypt(String text, String password, String roomId) {
    if (password.isEmpty || text.isEmpty) return text;
    try {
      final key = _getCachedKey(password, roomId, _iterationsForMessages);
      final iv = enc.IV.fromSecureRandom(12);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final encrypted = encrypter.encrypt(text, iv: iv);
      return "${iv.base64}:${encrypted.base64}";
    } catch (e) {
      debugPrint("Encrypt error: $e");
      return text;
    }
  }
  
  static String decrypt(String combinedData, String password, String roomId) {
    if (password.isEmpty || !combinedData.contains(':')) return combinedData;
    try {
      final parts = combinedData.split(':');
      final iv = enc.IV.fromBase64(parts[0]);
      final key = _getCachedKey(password, roomId, _iterationsForMessages);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      return encrypter.decrypt(enc.Encrypted.fromBase64(parts[1]), iv: iv);
    } catch (e) {
      debugPrint("Decrypt error: $e");
      return "[Ошибка расшифровки]";
    }
  }
  
  // --- КЛЮЧ ДЛЯ FIRESTORE (вычисляется 1 раз) ---
  static String deriveRoomKey(String password, String salt) {
    if (password.isEmpty) return "default_room_key";
    final key = _deriveKey(password, salt, _iterationsForRoomKey);
    return base64Url.encode(key.bytes);
  }
  
  // --- ВНУТРЕННИЕ МЕТОДЫ ---
  static enc.Key _getCachedKey(String password, String salt, int iterations) {
    final cacheKey = "$password|$salt|$iterations";
    
    if (_roomKeyCache.containsKey(cacheKey)) {
      return _roomKeyCache[cacheKey]!;
    }
    
    final key = _deriveKey(password, salt, iterations);
    _roomKeyCache[cacheKey] = key;
    
    // Ограничиваем размер кэша (чтобы не течь память)
    if (_roomKeyCache.length > 50) {
      _roomKeyCache.clear();
    }
    
    return key;
  }
  
  static enc.Key _deriveKey(String password, String salt, int iterations) {
    if (password.isEmpty) return enc.Key(Uint8List(32));
    
    final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pkcs.init(Pbkdf2Parameters(
      utf8.encode(salt),
      iterations,
      32
    ));
    
    return enc.Key(pkcs.process(utf8.encode(password)));
  }
  
  // Очистка кэша при выходе
  static void clearCache() {
    _roomKeyCache.clear();
  }
}