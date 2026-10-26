import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/carbon_calculation.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

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
      version: 2,
      onCreate: (db, version) async {
        await _createDb(db, version);
        await _createUsersTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createUsersTable(db);
        }
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
        password_hash TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE carbon_calculations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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

  Future<int> insertCalculation(CarbonCalculation calculation) async {
    final db = await database;
    return db.insert('carbon_calculations', calculation.toMap());
  }

  Future<int> insertUser({
    required String name,
    required String email,
    required String passwordSalt,
    required String passwordHash,
  }) async {
    final db = await database;
    return db.insert('users', {
      'name': name,
      'email': email,
      'password_salt': passwordSalt,
      'password_hash': passwordHash,
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

  Future<List<CarbonCalculation>> getAllCalculations() async {
    final db = await database;
    final rows = await db.query(
      'carbon_calculations',
      orderBy: 'id DESC',
    );
    return rows.map(CarbonCalculation.fromMap).toList();
  }

  Future<CarbonCalculation?> getCalculationById(int id) async {
    final db = await database;
    final rows = await db.query(
      'carbon_calculations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CarbonCalculation.fromMap(rows.first);
  }

  Future<int> deleteCalculation(int id) async {
    final db = await database;
    return db.delete(
      'carbon_calculations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('carbon_calculations');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
