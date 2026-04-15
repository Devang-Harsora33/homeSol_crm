import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../models/app_asset.dart';

class AssetDatabase {
  static final AssetDatabase _instance = AssetDatabase._internal();
  static Database? _database;

  factory AssetDatabase() {
    return _instance;
  }

  AssetDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_assets.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_assets(
        name TEXT PRIMARY KEY,
        data TEXT
      )
    ''');
  }

  Future<void> upsertAsset(AppAsset asset) async {
    final db = await database;
    await db.insert(
      'app_assets',
      {
        'name': asset.name,
        'data': json.encode(asset.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppAsset>> getAssets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('app_assets');
    return maps.map((map) => AppAsset.fromJson(json.decode(map['data']))).toList();
  }

  Future<void> deleteAllAssets() async {
    final db = await database;
    await db.delete('app_assets');
  }
}
