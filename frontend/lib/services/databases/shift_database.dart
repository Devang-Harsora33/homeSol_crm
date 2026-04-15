import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class ShiftDatabase {
  static final ShiftDatabase _instance = ShiftDatabase._internal();
  static Database? _database;

  factory ShiftDatabase() {
    return _instance;
  }

  ShiftDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_shift.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shift_types(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT
      )
    ''');
  }

  Future<void> saveShiftTypes(List<dynamic> shiftTypes) async {
    final db = await database;
    await db.delete('shift_types'); // Clear old data
    final String data = json.encode(shiftTypes);
    await db.insert(
      'shift_types',
      {'data': data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<dynamic>> getShiftTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query('shift_types');
    if (results.isNotEmpty) {
      return json.decode(results.first['data']);
    }
    return [];
  }

  Future<void> deleteShiftTypes() async {
    final db = await database;
    await db.delete('shift_types');
  }
}
