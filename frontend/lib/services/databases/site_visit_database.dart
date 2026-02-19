import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/site_visit.dart';

class SiteVisitDatabase {
  static const String tableName = 'site_visits';
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
    final path = join(dbPath, 'site_visits.db');

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

  static Future<void> upsertSiteVisit(SiteVisit siteVisit) async {
    final db = await database;
    await db.insert(
      tableName,
      {
        'id': siteVisit.name,
        'modified': siteVisit.modified,
        'data': jsonEncode({
          'name': siteVisit.name,
          'owner': siteVisit.owner,
          'creation': siteVisit.creation,
          'modified': siteVisit.modified,
          'modified_by': siteVisit.modifiedBy,
          'docstatus': siteVisit.docstatus,
          'idx': siteVisit.idx,
          'lead': siteVisit.lead,
          'project': siteVisit.project,
          'remark': siteVisit.remark,
          'visit_date': siteVisit.visitDate,
          'status': siteVisit.status,
          'visit_scheduled_datetime': siteVisit.visitScheduledDatetime,
          'doctype': siteVisit.doctype,
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<SiteVisit>> getAllSiteVisits() async {
    final db = await database;
    final results = await db.query(tableName);
    return results.map((map) {
      final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
      return SiteVisit.fromJson(data);
    }).toList();
  }

  static Future<SiteVisit?> getSiteVisitByName(String name) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [name],
    );

    if (results.isEmpty) return null;

    final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
    return SiteVisit.fromJson(data);
  }

  static Future<void> deleteSiteVisit(String name) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [name],
    );
  }

  static Future<void> deleteAllSiteVisits() async {
    final db = await database;
    await db.delete(tableName);
  }
}
