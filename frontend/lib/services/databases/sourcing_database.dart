import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class SourcingDatabase {
  static final SourcingDatabase _instance = SourcingDatabase._internal();
  static Database? _database;
  static Database? _testDatabase;

  factory SourcingDatabase() {
    return _instance;
  }

  SourcingDatabase._internal();

  static void setDatabaseForTesting(Database? db) {
    _testDatabase = db;
  }

  Future<Database> get database async {
    if (_testDatabase != null) return _testDatabase!;
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_sourcing.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sourcing(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertSourcing(Map<String, dynamic> sourcing) async {
    final db = await database;
    final String name = sourcing['name'] ?? '';
    final String modified = sourcing['modified'] ?? '';
    final String data = json.encode(sourcing);

    List<Map<String, dynamic>> existing = await db.query(
      'sourcing',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existing.isNotEmpty) {
      await db.update(
        'sourcing',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      await db.insert(
        'sourcing',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllSourcing() async {
    final db = await database;
    return await db.query('sourcing');
  }

  Future<void> deleteSourcing(String name) async {
    final db = await database;
    await db.delete(
      'sourcing',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllSourcing() async {
    final db = await database;
    await db.delete('sourcing');
  }
}
