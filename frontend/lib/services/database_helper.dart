import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('homesol_notifications.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT,
        story_id TEXT,
        created_at TEXT,
        developer_name TEXT,
        developer_logo TEXT,
        title TEXT,
        body TEXT,
        is_read INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> insertNotification(Map<String, dynamic> notification) async {
    final db = await instance.database;
    await db.insert(
      'notifications',
      notification,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final db = await instance.database;
    return await db.query('notifications', orderBy: 'created_at DESC');
  }

  Future<int> getUnreadCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM notifications WHERE is_read = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAllAsRead() async {
    final db = await instance.database;
    await db.update('notifications', {'is_read': 1});
  }

  Future<void> deleteNotification(String id) async {
    final db = await instance.database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('notifications');
  }

  Future<void> close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
