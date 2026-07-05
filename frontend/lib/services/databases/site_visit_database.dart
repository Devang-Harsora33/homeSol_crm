import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/site_visit.dart';

class SiteVisitDatabase {
  static const String tableName = 'site_visits';
  static Database? _database;
  static Database? _testDatabase;

  static void setDatabaseForTesting(Database? db) {
    _testDatabase = db;
  }

  static Future<Database> get database async {
    if (_testDatabase != null) return _testDatabase!;
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

    // Fetch existing data to avoid overwriting rich details with partial list data
    final existingResults = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [siteVisit.name],
    );

    Map<String, dynamic> dataToSave = {
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
      'presence_of_cp': siteVisit.presenceOfCp,
      'visit_duration': siteVisit.visitDuration,
      'doctype': siteVisit.doctype,
    };

    if (existingResults.isNotEmpty) {
      try {
        final existingData = jsonDecode(existingResults.first['data'] as String) as Map<String, dynamic>;
        
        // Preserve rich fields if new data is null or empty
        if ((siteVisit.visitDuration == null || siteVisit.visitDuration!.isEmpty) && 
            existingData['visit_duration'] != null) {
          dataToSave['visit_duration'] = existingData['visit_duration'];
        }
        
        if (siteVisit.presenceOfCp == null && existingData['presence_of_cp'] != null) {
          dataToSave['presence_of_cp'] = existingData['presence_of_cp'];
        }

        if ((siteVisit.visitScheduledDatetime == null || siteVisit.visitScheduledDatetime!.isEmpty) && 
            existingData['visit_scheduled_datetime'] != null) {
          dataToSave['visit_scheduled_datetime'] = existingData['visit_scheduled_datetime'];
        }
      } catch (e) {
        print('Error merging site visit data: $e');
      }
    }

    await db.insert(
      tableName,
      {
        'id': siteVisit.name,
        'modified': siteVisit.modified,
        'data': jsonEncode(dataToSave),
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
