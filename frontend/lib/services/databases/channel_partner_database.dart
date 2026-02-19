import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class ChannelPartnerDatabase {
  static final ChannelPartnerDatabase _instance = ChannelPartnerDatabase._internal();
  static Database? _database;

  factory ChannelPartnerDatabase() {
    return _instance;
  }

  ChannelPartnerDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'homesol_channel_partners.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE channel_partners(
        name TEXT PRIMARY KEY,
        modified TEXT,
        data TEXT
      )
    ''');
  }

  Future<void> upsertChannelPartner(Map<String, dynamic> partner) async {
    final db = await database;
    final String name = partner['name'];
    final String modified = partner['modified'];
    final String data = json.encode(partner); // Store the entire JSON object as a string

    // Check if the record exists
    List<Map<String, dynamic>> existingPartner = await db.query(
      'channel_partners',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingPartner.isNotEmpty) {
      // Update existing record
      await db.update(
        'channel_partners',
        {'modified': modified, 'data': data},
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // Insert new record
      await db.insert(
        'channel_partners',
        {'name': name, 'modified': modified, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllChannelPartners() async {
    final db = await database;
    return await db.query('channel_partners');
  }

  Future<Map<String, dynamic>?> getChannelPartnerByName(String name) async {
    final db = await database;
    List<Map<String, dynamic>> partners = await db.query(
      'channel_partners',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (partners.isNotEmpty) {
      return json.decode(partners.first['data']);
    }
    return null;
  }

  Future<void> deleteChannelPartner(String name) async {
    final db = await database;
    await db.delete(
      'channel_partners',
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> deleteAllChannelPartners() async {
    final db = await database;
    await db.delete('channel_partners');
  }
}
