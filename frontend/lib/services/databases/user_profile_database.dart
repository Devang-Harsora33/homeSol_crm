import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class UserProfileDatabase {
  static final UserProfileDatabase _instance = UserProfileDatabase._internal();
  static Database? _database;

  factory UserProfileDatabase() {
    return _instance;
  }

  UserProfileDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_user_profile.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertUserProfile(Map<String, dynamic> profile) async {
    final db = await database;
    final String name = profile['name'];
    final String modified = profile['modified'];
    final String data = json.encode(profile); // Store the entire JSON object as a string

    // Check if the record exists
    List<Map<String, dynamic>> existingProfile = await db.query(
      'user_profile',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingProfile.isNotEmpty) {
      // Update existing record
      await db.update(
        'user_profile',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // Insert new record
      await db.insert(
        'user_profile',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    List<Map<String, dynamic>> profiles = await db.query('user_profile');
    if (profiles.isNotEmpty) {
      return json.decode(profiles.first['data']);
    }
    return null;
  }

  Future<void> deleteUserProfile(String name) async {
    final db = await database;
    await db.delete(
      'user_profile',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllUserProfiles() async {
    final db = await database;
    await db.delete('user_profile');
  }
}
