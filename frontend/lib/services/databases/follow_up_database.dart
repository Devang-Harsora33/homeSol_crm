import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/follow_up.dart';

class FollowUpDatabase {
  static const String tableName = 'follow_ups';
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
    final path = join(dbPath, 'follow_ups.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE $tableName (
            id TEXT PRIMARY KEY,
            modified TEXT,
            data TEXT
          )''',
        );
      },
    );
  }

  static Future<void> upsertFollowUp(FollowUp followUp) async {
    final db = await database;
    await db.insert(
      tableName,
      {
        'id': followUp.name,
        'modified': followUp.modified,
        'data': jsonEncode({
          'name': followUp.name,
          'follow_up_date': followUp.followUpDate,
          'status': followUp.status,
          'type': followUp.type,
          'remarks': followUp.remarks,
          'next_follow_up': followUp.nextFollowUp,
          'parent': followUp.parent,
          'assigned_to': followUp.assignedTo,
          'lead_id': followUp.leadId,
          'lead_name': followUp.leadName,
          'mobile_no': followUp.mobileNo,
          'owner': followUp.leadOwner,
          'creation': followUp.creation,
          'modified': followUp.modified,
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<FollowUp>> getAllFollowUps() async {
    final db = await database;
    final results = await db.query(tableName);
    return results.map((map) {
      final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
      return FollowUp.fromJson(data);
    }).toList();
  }

  static Future<FollowUp?> getFollowUpByName(String name) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [name],
    );

    if (results.isEmpty) return null;

    final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
    return FollowUp.fromJson(data);
  }

  static Future<void> deleteFollowUp(String name) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [name],
    );
  }

  static Future<void> deleteAllFollowUps() async {
    final db = await database;
    await db.delete(tableName);
  }
}
