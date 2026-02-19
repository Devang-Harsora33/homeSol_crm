import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/ticket.dart';

class TicketDatabase {
  static const String tableName = 'tickets';
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
    final path = join(dbPath, 'tickets.db');

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

  static Future<void> upsertTicket(Ticket ticket) async {
    final db = await database;
    await db.insert(
      tableName,
      {
        'id': ticket.id,
        'modified': ticket.modified,
        'data': jsonEncode({
          'name': ticket.id,
          'status': ticket.status,
          'priority': ticket.priority,
          'category': ticket.category,
          'description': ticket.description,
          'raised_by': ticket.raisedBy,
          'creation': ticket.creation,
          'docstatus': ticket.docstatus,
          'doctype': ticket.doctype,
          'idx': ticket.idx,
          'modified': ticket.modified,
          'owner': ticket.owner,
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Ticket>> getAllTickets() async {
    final db = await database;
    final results = await db.query(tableName);
    return results.map((map) {
      final data = jsonDecode(map['data'] as String) as Map<String, dynamic>;
      return Ticket.fromJson(data);
    }).toList();
  }

  static Future<Ticket?> getTicketById(String id) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final data = jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
    return Ticket.fromJson(data);
  }

  static Future<void> deleteTicket(String id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteAllTickets() async {
    final db = await database;
    await db.delete(tableName);
  }
}
