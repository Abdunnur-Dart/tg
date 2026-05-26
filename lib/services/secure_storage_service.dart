import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // Создаём экземпляр защищённого хранилища
  static final _storage = FlutterSecureStorage();
  
  // Ключи для разных типов данных
  static const String _roomPasswordsKey = 'secure_room_passwords';
  static const String _pinCodeKey = 'secure_pin_code';
  
  // --- РАБОТА С ПАРОЛЯМИ КОМНАТ ---
  
  // Сохраняем все пароли комнат (как JSON строку)
  static Future<void> saveRoomPasswords(Map<String, String> passwords) async {
    try {
      // Превращаем карту в JSON строку
      final jsonString = _mapToJson(passwords);
      // Сохраняем в защищённое хранилище
      await _storage.write(key: _roomPasswordsKey, value: jsonString);
    } catch (e) {
      print("Ошибка сохранения паролей: $e");
    }
  }
  
  // Загружаем все пароли комнат
  static Future<Map<String, String>> loadRoomPasswords() async {
    try {
      final jsonString = await _storage.read(key: _roomPasswordsKey);
      if (jsonString == null) return {};
      return _jsonToMap(jsonString);
    } catch (e) {
      print("Ошибка загрузки паролей: $e");
      return {};
    }
  }
  
  // Сохраняем пароль для одной комнаты
  static Future<void> saveRoomPassword(String roomId, String password) async {
    final passwords = await loadRoomPasswords();
    passwords[roomId] = password;
    await saveRoomPasswords(passwords);
  }
  
  // Удаляем пароль комнаты
  static Future<void> removeRoomPassword(String roomId) async {
    final passwords = await loadRoomPasswords();
    passwords.remove(roomId);
    await saveRoomPasswords(passwords);
  }
  
  // --- РАБОТА С PIN-КОДОМ ---
  
  static Future<void> savePinCode(String? hashedPin) async {
    if (hashedPin == null) {
      await _storage.delete(key: _pinCodeKey);
    } else {
      await _storage.write(key: _pinCodeKey, value: hashedPin);
    }
  }
  
  static Future<String?> loadPinCode() async {
    return await _storage.read(key: _pinCodeKey);
  }
  
  // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
  
  static String _mapToJson(Map<String, String> map) {
    // Простое преобразование без json.encode для наглядности
    final List<String> pairs = [];
    map.forEach((key, value) {
      // Экранируем служебные символы
      final safeKey = key.replaceAll('|', '\\|');
      final safeValue = value.replaceAll('|', '\\|');
      pairs.add('$safeKey|$safeValue');
    });
    return pairs.join('||');
  }
  
  static Map<String, String> _jsonToMap(String json) {
    final Map<String, String> result = {};
    final parts = json.split('||');
    for (var part in parts) {
      if (part.isEmpty) continue;
      final pair = part.split('|');
      if (pair.length == 2) {
        // Восстанавливаем экранированные символы
        final key = pair[0].replaceAll('\\|', '|');
        final value = pair[1].replaceAll('\\|', '|');
        result[key] = value;
      }
    }
    return result;
  }
  
  // Очистка всех данных при выходе
  static Future<void> clearAll() async {
    await _storage.delete(key: _roomPasswordsKey);
    await _storage.delete(key: _pinCodeKey);
  }
}