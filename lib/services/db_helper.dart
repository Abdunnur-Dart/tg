import 'dart:io';
import 'dart:convert';
import 'dart:math';

// 1. SQLCipher для мобильных (шифрование)
import 'package:sqflite_sqlcipher/sqflite.dart' as sql; 
// 2. FFI для Desktop (Windows/Linux)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// 3. Базовый API (нужен для переменной databaseFactory)

import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; 
import '../models/message_model.dart';

class DBHelper {
  static sql.Database? _db;
  static const _storage = FlutterSecureStorage();
  static const _dbEncryptionKeyName = 'telegraph_db_master_key_v31';

  // --- ИНИЦИАЛИЗАЦИЯ И ЗАЩИТА ---

  static Future<String> _getSecureEncryptionKey() async {
    String? key = await _storage.read(key: _dbEncryptionKeyName);
    if (key == null) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64Url.encode(values);
      await _storage.write(key: _dbEncryptionKeyName, value: key);
    }
    return key;
  }

  static Future<sql.Database> get database async {
    if (_db != null) return _db!;

    // В Web SQLite не поддерживается
    if (kIsWeb) {
      throw UnsupportedError("SQLite не поддерживается в Web режиме.");
    }

    // Инициализация для Windows/Linux
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      // Убрали "sql.", теперь ошибки компиляции не будет
      databaseFactory = databaseFactoryFfi; 
    }

    final encryptionKey = await _getSecureEncryptionKey();
    final dbPath = await sql.getDatabasesPath();
    final path = p.join(dbPath, 'telegraph_v31.db');

    _db = await sql.openDatabase(
      path,
      password: encryptionKey, // Шифрование всей БД
      version: 1,
      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            content TEXT,
            username TEXT,
            user_id TEXT,
            room_id TEXT,
            created_at TEXT,
            is_image INTEGER DEFAULT 0
          )
        ''');
      },
    );

    return _db!;
  }

  // --- МЕТОДЫ РАБОТЫ С ДАННЫМИ ---

  // Метод для сохранения (нужен для ChatViewModel)
  static Future<void> saveLocal(MessageModel message) async {
    if (kIsWeb) return; 
    try {
      final db = await database;
      await db.insert(
        'messages', 
        message.toMap(),
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("DB Save Error: $e");
    }
  }

  static Future<List<MessageModel>> getLocal(String roomId) async {
    if (kIsWeb) return []; 
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'room_id = ?',
        whereArgs: [roomId],
        orderBy: 'created_at ASC',
      );
      return List.generate(maps.length, (i) => MessageModel.fromMap(maps[i]));
    } catch (e) {
      debugPrint("DB Read Error: $e");
      return [];
    }
  }

  static Future<void> deleteMessage(String id) async {
    if (kIsWeb) return; 
    try {
      final db = await database;
      await db.delete('messages', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint("DB Delete Error: $e");
    }
  }

  static Future<void> clearRoom(String roomId) async {
    if (kIsWeb) return;
    try {
      final db = await database;
      await db.delete('messages', where: 'room_id = ?', whereArgs: [roomId]);
    } catch (e) {
      debugPrint("DB Clear Room Error: $e");
    }
  }

  // ТОТ САМЫЙ МЕТОД: Очистка всей базы (нужен для SettingsPage)
  static Future<void> clearAll() async {
    if (kIsWeb) return;
    try {
      final db = await database;
      await db.delete('messages');
      debugPrint("Локальная база данных очищена успешно");
    } catch (e) {
      debugPrint("DB ClearAll Error: $e");
    }
  }
}