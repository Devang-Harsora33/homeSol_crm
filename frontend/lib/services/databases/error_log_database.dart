import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/error_log.dart';

class ErrorLogDatabase {
  static const String tableName = 'error_logs';
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initializeDatabase();
    return _database!;
  }

  static Future<Database> _initializeDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'error_logs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user TEXT,
            log_level TEXT,
            module TEXT,
            action TEXT,
            message TEXT,
            device_info TEXT,
            stack_trace TEXT,
            timestamp TEXT
          )''',
        );
      },
    );
  }

  static Future<int> insertErrorLog(ErrorLog log) async {
    final db = await database;
    return await db.insert(
      tableName,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ErrorLog>> getAllErrorLogs() async {
    final db = await database;
    final results = await db.query(tableName, orderBy: 'timestamp DESC');
    return results.map((map) => ErrorLog.fromMap(map)).toList();
  }

  static Future<List<ErrorLog>> getRecentErrorLogs(int limit) async {
    final db = await database;
    final results = await db.query(
      tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((map) => ErrorLog.fromMap(map)).toList();
  }

  static Future<void> deleteErrorLog(int id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearAllLogs() async {
    final db = await database;
    await db.delete(tableName);
  }
}
