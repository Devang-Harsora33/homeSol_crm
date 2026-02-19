import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DeveloperDatabase {
  static final DeveloperDatabase _instance = DeveloperDatabase._internal();
  static Database? _database;

  factory DeveloperDatabase() {
    return _instance;
  }

  DeveloperDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_developers.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE developers(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertDeveloper(Map<String, dynamic> developer) async {
    final db = await database;
    final String name = developer['name'];
    final String modified = developer['modified'];
    final String data = json.encode(developer); // Store the entire JSON object as a string

    // Check if the record exists
    List<Map<String, dynamic>> existingDeveloper = await db.query(
      'developers',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingDeveloper.isNotEmpty) {
      // Update existing record
      await db.update(
        'developers',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // Insert new record
      await db.insert(
        'developers',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllDevelopers() async {
    final db = await database;
    return await db.query('developers');
  }

  Future<Map<String, dynamic>?> getDeveloperByName(String name) async {
    final db = await database;
    List<Map<String, dynamic>> developers = await db.query(
      'developers',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (developers.isNotEmpty) {
      return json.decode(developers.first['data']);
    }
    return null;
  }

  Future<void> deleteDeveloper(String name) async {
    final db = await database;
    await db.delete(
      'developers',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllDevelopers() async {
    final db = await database;
    await db.delete('developers');
  }
}
