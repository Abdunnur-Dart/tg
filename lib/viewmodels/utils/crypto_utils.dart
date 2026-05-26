import 'dart:math';
import 'dart:convert';

class CryptoUtils {
  static final Random _random = Random.secure();
  
  /// Генерирует криптостойкий случайный пароль
  static String generateStrongPassword({int length = 32}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()-_=+[]{}<>?';
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(_random.nextInt(chars.length)))
    );
  }
  
  /// Альтернативный метод: Base64 URL-safe ключ
  static String generateSecureKey({int bytes = 32}) {
    final values = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64Url.encode(values);
  }
}