import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/app_activity.dart';
import '../models/carbon_calculation.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;
  static const _sessionUserIdKey = 'lumen.session.user_id';
  final _preferences = SharedPreferencesAsync();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final databasePath = kIsWeb
        ? 'ecometer.db'
        : p.join(await getDatabasesPath(), 'ecometer.db');

    return openDatabase(
      databasePath,
      version: 5,
      onCreate: (db, version) async {
        await _createDb(db, version);
        await _createUsersTable(db);
        await _createActivityTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createUsersTable(db);
        }
        if (oldVersion >= 2 && oldVersion < 3) {
          await db.execute(
            "ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'USER' "
            "CHECK (role IN ('USER', 'ADMIN'))",
          );
          await db.execute('ALTER TABLE users ADD COLUMN created_at TEXT');
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE carbon_calculations ADD COLUMN user_id INTEGER '
            'REFERENCES users(id) ON DELETE SET NULL',
          );
        }
        if (oldVersion < 5) await _createActivityTable(db);
      },
    );
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL COLLATE NOCASE UNIQUE,
        password_salt TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN')),
        created_at TEXT
      )
    ''');
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE carbon_calculations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        date TEXT NOT NULL,
        transport_emission REAL NOT NULL,
        electricity_emission REAL NOT NULL,
        food_emission REAL NOT NULL,
        travel_emission REAL NOT NULL,
        total_emission REAL NOT NULL,
        transport_distance REAL,
        electricity_units REAL,
        food_type TEXT,
        travel_distance REAL,
        travel_type TEXT
      )
    ''');
  }

  Future<void> _createActivityTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        event_type TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        details TEXT,
        dedupe_key TEXT NOT NULL UNIQUE
      )
    ''');
  }

  Future<void> _insertActivity(
    DatabaseExecutor db, {
    required int? userId,
    required String eventType,
    required String dedupeKey,
    String? details,
    String? occurredAt,
  }) async {
    await db.insert('activity_logs', {
      'user_id': userId,
      'event_type': eventType,
      'occurred_at': occurredAt ?? DateTime.now().toUtc().toIso8601String(),
      'details': details,
      'dedupe_key': dedupeKey,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> _requireSignedInUser([int? expectedUserId]) async {
    final userId = await _preferences.getInt(_sessionUserIdKey);
    if (userId == null ||
        (expectedUserId != null && userId != expectedUserId)) {
      throw StateError('A matching signed-in user is required.');
    }
    return userId;
  }

  Future<void> _requireAdmin(DatabaseExecutor db) async {
    final userId = await _requireSignedInUser();
    final rows = await db.query(
      'users',
      columns: ['role'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['role'] != 'ADMIN') {
      throw StateError('Administrator authorization is required.');
    }
  }

  Future<void> recordActivity({
    required int userId,
    required String eventType,
    required String dedupeKey,
    String? details,
  }) async {
    final db = await database;
    await _requireSignedInUser(userId);
    await _insertActivity(
      db,
      userId: userId,
      eventType: eventType,
      dedupeKey: dedupeKey,
      details: details,
    );
  }

  Future<int> insertCalculation(CarbonCalculation calculation) =>
      saveCalculation(calculation);

  Future<int> saveCalculation(CarbonCalculation calculation) async {
    final db = await database;
    if (calculation.userId == null) {
      throw ArgumentError.value(
        calculation.userId,
        'calculation.userId',
        'A saved calculation must belong to a signed-in user.',
      );
    }
    await _requireSignedInUser(calculation.userId);
    return db.transaction((transaction) async {
      final calculationId = await transaction.insert(
        'carbon_calculations',
        calculation.toMap(),
      );
      await _insertActivity(
        transaction,
        userId: calculation.userId,
        eventType: 'calculation_saved',
        dedupeKey: 'calculation-saved:$calculationId',
        details:
            'Saved estimate of ${calculation.totalEmission.toStringAsFixed(2)} tCO2e/year.',
        occurredAt: calculation.date,
      );
      return calculationId;
    });
  }

  Future<int> insertUser({
    required String name,
    required String email,
    required String passwordSalt,
    required String passwordHash,
  }) async {
    final db = await database;
    return db.transaction((transaction) async {
      final registeredAt = DateTime.now().toUtc().toIso8601String();
      final userId = await transaction.insert('users', {
        'name': name,
        'email': email,
        'password_salt': passwordSalt,
        'password_hash': passwordHash,
        'created_at': registeredAt,
      });
      await _insertActivity(
        transaction,
        userId: userId,
        eventType: 'registration_succeeded',
        dedupeKey: 'registration:$userId',
        occurredAt: registeredAt,
      );
      return userId;
    });
  }

  Future<Map<String, Object?>?> getUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getAdminDashboardUsers() async {
    final db = await database;
    await _requireAdmin(db);
    return db.query(
      'users',
      columns: ['id', 'name', 'email', 'role', 'created_at'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<int> getUserCount() async {
    final db = await database;
    await _requireAdmin(db);
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM users');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> getAdminCount() async {
    final db = await database;
    await _requireAdmin(db);
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM users WHERE role = 'ADMIN'",
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> getCalculationCount() async {
    final db = await database;
    await _requireAdmin(db);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM carbon_calculations',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> getActivityCount() async {
    final db = await database;
    await _requireAdmin(db);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM activity_logs',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<double> getTotalEmissions() async {
    final db = await database;
    await _requireAdmin(db);
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total_emission), 0) AS total FROM carbon_calculations',
    );
    return (rows.single['total'] as num).toDouble();
  }

  Future<List<Map<String, Object?>>> getAdminCalculationRows() async {
    final db = await database;
    await _requireAdmin(db);
    return db.rawQuery('''
      SELECT c.*, u.name AS user_name, u.email AS user_email
      FROM carbon_calculations c
      LEFT JOIN users u ON u.id = c.user_id
      ORDER BY c.date DESC, c.id DESC
    ''');
  }

  Future<List<AppActivity>> getAdminActivityRows() async {
    final db = await database;
    await _requireAdmin(db);
    final rows = await db.rawQuery('''
      SELECT a.id, a.user_id, a.event_type, a.occurred_at, a.details,
             u.name AS user_name, u.email AS user_email
      FROM activity_logs a
      LEFT JOIN users u ON u.id = a.user_id
      ORDER BY a.occurred_at DESC, a.id DESC
    ''');
    return rows.map(AppActivity.fromMap).toList();
  }

  Future<bool> promoteFirstAdmin(int userId) async {
    await _requireSignedInUser(userId);
    final db = await database;
    return db.transaction((transaction) async {
      final rows = await transaction.rawQuery(
        "SELECT COUNT(*) AS count FROM users WHERE role = 'ADMIN'",
      );
      if ((Sqflite.firstIntValue(rows) ?? 0) != 0) return false;
      final updated = await transaction.update(
        'users',
        {'role': 'ADMIN'},
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (updated == 1) {
        await _insertActivity(
          transaction,
          userId: userId,
          eventType: 'admin_setup',
          dedupeKey: 'first-admin-setup:$userId',
          details: 'Initial administrator setup completed.',
        );
      }
      return updated == 1;
    });
  }

  Future<bool> hasAdministrator() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS count FROM users WHERE role = 'ADMIN'",
    );
    return (Sqflite.firstIntValue(rows) ?? 0) > 0;
  }

  Future<List<CarbonCalculation>> getAllCalculations({
    required int userId,
  }) async {
    await _requireSignedInUser(userId);
    final db = await database;
    final rows = await db.query(
      'carbon_calculations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(CarbonCalculation.fromMap).toList();
  }

  Future<CarbonCalculation?> getCalculationById(
    int id, {
    required int userId,
  }) async {
    await _requireSignedInUser(userId);
    final db = await database;
    final rows = await db.query(
      'carbon_calculations',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CarbonCalculation.fromMap(rows.first);
  }

  Future<int> deleteCalculation(int id, {required int userId}) async {
    await _requireSignedInUser(userId);
    final db = await database;
    return db.transaction((transaction) async {
      final rows = await transaction.query(
        'carbon_calculations',
        columns: ['total_emission', 'date'],
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      final deleted = await transaction.delete(
        'carbon_calculations',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      if (deleted == 1) {
        await _insertActivity(
          transaction,
          userId: userId,
          eventType: 'calculation_deleted',
          dedupeKey: 'calculation-deleted:$id',
          details:
              'Deleted saved estimate of ${(rows.first['total_emission'] as num).toStringAsFixed(2)} tCO2e/year.',
        );
      }
      return deleted;
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
