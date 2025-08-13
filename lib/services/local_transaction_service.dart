import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalTransactionService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'transactions.db');

    return await openDatabase(
      path,
      version: 6, // ✅ bumped to version 5
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_name TEXT,
            items TEXT,
            total_price REAL,
            created_at TEXT,
            synced INTEGER DEFAULT 0,
            remote_id TEXT,
            reference_number TEXT,
            status TEXT DEFAULT 'unpaid',
            payment TEXT DEFAULT 'cash',
            dirty INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        Future<bool> columnExists(String tableName, String columnName) async {
          final result = await db.rawQuery('PRAGMA table_info($tableName)');
          return result.any((column) => column['name'] == columnName);
        }

        if (oldVersion < 2) {
          if (!await columnExists('transactions', 'remote_id')) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN remote_id TEXT",
            );
          }
        }
        if (oldVersion < 3) {
          if (!await columnExists('transactions', 'reference_number')) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN reference_number TEXT",
            );
          }
        }
        if (oldVersion < 4) {
          if (!await columnExists('transactions', 'status')) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT 'unpaid'",
            );
          }
        }
        if (oldVersion < 5) {
          if (!await columnExists('transactions', 'dirty')) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN dirty INTEGER DEFAULT 0",
            );
          }
        }
        if (oldVersion < 6) {
          if (!await columnExists('transactions', 'payment')) {
            await db.execute(
              "ALTER TABLE transactions ADD COLUMN payment TEXT DEFAULT 'cash'",
            );
          }
        }
      },
    );
  }

  Future<String> insertTransaction({
    String? customerName,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    String status = 'unpaid',
    String payment = 'cash',
  }) async {
    final db = await database;
    final millis = DateTime.now().millisecondsSinceEpoch % 1000000;
    final rand = DateTime.now().microsecondsSinceEpoch % 100;
    final referenceNumber =
        'REF${millis.toString().padLeft(6, '0')}${rand.toString().padLeft(2, '0')}';

    await db.insert('transactions', {
      'customer_name': customerName,
      'items': jsonEncode(items),
      'total_price': totalPrice,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
      'remote_id': null,
      'reference_number': referenceNumber,
      'status': status,
      'payment': payment,
      'dirty': 0,
    });

    return referenceNumber;
  }

  Future<void> updateTransactionStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'transactions',
      {'status': status, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTransactionPayment(int id, String payment) async {
    final db = await database;
    await db.update(
      'transactions',
      {'payment': payment, 'dirty': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await database;
    return await db.query('transactions', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getDirtyTransactions() async {
    final db = await database;
    return await db.query(
      'transactions',
      where: 'dirty = 1 AND remote_id IS NOT NULL',
    );
  }

  Future<void> clearDirtyFlag(int id) async {
    final db = await database;
    await db.update(
      'transactions',
      {'dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsSynced(int id, String remoteId) async {
    final db = await database;
    await db.update(
      'transactions',
      {'synced': 1, 'remote_id': remoteId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllTransactions({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (start != null && end != null) {
      where = 'created_at BETWEEN ? AND ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    }

    return await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getRemoteId(int id) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['remote_id'] as String?;
    }
    return null;
  }
}
