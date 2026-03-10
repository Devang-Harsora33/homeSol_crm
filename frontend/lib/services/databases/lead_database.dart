import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class LeadDatabase {
  static final LeadDatabase _instance = LeadDatabase._internal();
  static Database? _database; // For production use
  static Database? _testDatabase; // For testing use

  factory LeadDatabase() {
    return _instance;
  }

  LeadDatabase._internal();

  // Static method to inject a database for testing
  static void setDatabaseForTesting(Database? db) {
    _testDatabase = db;
  }

  Future<Database> get database async {
    if (_testDatabase != null) return _testDatabase!; // Use test database if injected
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_leads.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE leads(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertLead(Map<String, dynamic> lead) async {
    final db = await database;
    final String name = lead['name'];
    final String modified = lead['modified'];
    final String data = json.encode(lead); // Store the entire JSON object as a string

    // Check if the record exists
    List<Map<String, dynamic>> existingLead = await db.query(
      'leads',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingLead.isNotEmpty) {
      // Update existing record
      await db.update(
        'leads',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // Insert new record
      await db.insert(
        'leads',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllLeads() async {
    final db = await database;
    return await db.query('leads');
  }

  Future<Map<String, dynamic>?> getLeadByName(String name) async {
    final db = await database;
    List<Map<String, dynamic>> leads = await db.query(
      'leads',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (leads.isNotEmpty) {
      return json.decode(leads.first['data']);
    }
    return null;
  }

  Future<void> deleteLead(String name) async {
    final db = await database;
    await db.delete(
      'leads',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllLeads() async {
    final db = await database;
    await db.delete('leads');
  }
}
