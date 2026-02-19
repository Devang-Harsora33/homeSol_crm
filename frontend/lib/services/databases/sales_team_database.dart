import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class SalesTeamDatabase {
  static final SalesTeamDatabase _instance = SalesTeamDatabase._internal();
  static Database? _database;

  factory SalesTeamDatabase() {
    return _instance;
  }

  SalesTeamDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_sales_teams.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sales_teams(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertSalesTeam(Map<String, dynamic> team) async {
    final db = await database;
    final String name = team['name'];
    final String modified = team['modified'];
    final String data = json.encode(team); // Store the entire JSON object as a string

    // Check if the record exists
    List<Map<String, dynamic>> existingTeam = await db.query(
      'sales_teams',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingTeam.isNotEmpty) {
      // Update existing record
      await db.update(
        'sales_teams',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // Insert new record
      await db.insert(
        'sales_teams',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllSalesTeams() async {
    final db = await database;
    return await db.query('sales_teams');
  }

  Future<Map<String, dynamic>?> getSalesTeamByName(String name) async {
    final db = await database;
    List<Map<String, dynamic>> teams = await db.query(
      'sales_teams',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (teams.isNotEmpty) {
      return json.decode(teams.first['data']);
    }
    return null;
  }

  Future<void> deleteSalesTeam(String name) async {
    final db = await database;
    await db.delete(
      'sales_teams',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllSalesTeams() async {
    final db = await database;
    await db.delete('sales_teams');
  }
}
