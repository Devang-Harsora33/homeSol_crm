import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class ProjectDatabase {
  static final ProjectDatabase _instance = ProjectDatabase._internal();
  static Database? _database;

  factory ProjectDatabase() {
    return _instance;
  }

  ProjectDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_projects.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertProject(Map<String, dynamic> project) async {
    final db = await database;
    final String name = project['name'];
    final String modified = project['modified'];
    final String data = json.encode(project); // Store the entire JSON object as a string

    // Check if the record exists
    List<Map<String, dynamic>> existingProject = await db.query(
      'projects',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingProject.isNotEmpty) {
      // Update existing record
      await db.update(
        'projects',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // Insert new record
      await db.insert(
        'projects',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllProjects() async {
    final db = await database;
    return await db.query('projects');
  }

  Future<Map<String, dynamic>?> getProjectByName(String name) async {
    final db = await database;
    List<Map<String, dynamic>> projects = await db.query(
      'projects',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (projects.isNotEmpty) {
      return json.decode(projects.first['data']);
    }
    return null;
  }

  Future<void> deleteProject(String name) async {
    final db = await database;
    await db.delete(
      'projects',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllProjects() async {
    final db = await database;
    await db.delete('projects');
  }
}
