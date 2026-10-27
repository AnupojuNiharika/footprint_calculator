import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/app_activity.dart';
import '../models/carbon_calculation.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isAdmin,
  });

  final int id;
  final String name;
  final String email;
  final bool isAdmin;

  factory AuthUser.fromMap(Map<String, Object?> row) => AuthUser(
    id: row['id'] as int,
    name: row['name'] as String,
    email: row['email'] as String,
    isAdmin: row['role'] == 'ADMIN',
  );
}

class AdminDashboardUser {
  const AdminDashboardUser({
    required this.name,
    required this.email,
    required this.isAdmin,
    required this.registeredAt,
  });

  final String name;
  final String email;
  final bool isAdmin;
  final DateTime? registeredAt;

  factory AdminDashboardUser.fromMap(Map<String, Object?> row) {
    final registeredAtValue = row['created_at'] as String?;
    return AdminDashboardUser(
      name: row['name'] as String,
      email: row['email'] as String,
      isAdmin: row['role'] == 'ADMIN',
      registeredAt: registeredAtValue == null
          ? null
          : DateTime.tryParse(registeredAtValue),
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.users,
    required this.calculations,
    required this.activities,
    required this.userCount,
    required this.adminCount,
    required this.calculationCount,
    required this.activityCount,
    required this.totalEmissions,
    required this.databaseAccessible,
  });

  final List<AdminDashboardUser> users;
  final List<AdminDashboardCalculation> calculations;
  final List<AppActivity> activities;
  final int userCount;
  final int adminCount;
  final int calculationCount;
  final int activityCount;
  final double totalEmissions;
  final bool databaseAccessible;
}

class AdminDashboardCalculation {
  const AdminDashboardCalculation({
    required this.calculation,
    required this.userName,
    required this.userEmail,
  });

  final CarbonCalculation calculation;
  final String? userName;
  final String? userEmail;

  factory AdminDashboardCalculation.fromMap(Map<String, Object?> row) =>
      AdminDashboardCalculation(
        calculation: CarbonCalculation.fromMap(row),
        userName: row['user_name'] as String?,
        userEmail: row['user_email'] as String?,
      );
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const _sessionUserIdKey = 'lumen.session.user_id';
  static const _sessionInstanceIdKey = 'lumen.session.instance_id';
  static final _passwordHasher = Pbkdf2.hmacSha256(
    iterations: 120000,
    bits: 256,
  );

  final _preferences = SharedPreferencesAsync();
  final _database = DatabaseHelper.instance;

  Future<AuthUser?> restoreSession() async {
    final userId = await _preferences.getInt(_sessionUserIdKey);
    if (userId == null) return null;

    final row = await _database.getUserById(userId);
    if (row == null) {
      await _preferences.remove(_sessionUserIdKey);
      await _preferences.remove(_sessionInstanceIdKey);
      return null;
    }
    if (await _preferences.getString(_sessionInstanceIdKey) == null) {
      await _preferences.setString(
        _sessionInstanceIdKey,
        _newSessionInstanceId(),
      );
    }
    return AuthUser.fromMap(row);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) throw const AuthException('Enter your name.');
    if (!_isValidEmail(cleanEmail)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 8) {
      throw const AuthException('Use a password with at least 8 characters.');
    }

    if (await _database.getUserByEmail(cleanEmail) != null) {
      throw const AuthException('An account with this email already exists.');
    }

    final salt = List<int>.generate(
      16,
      (_) => SecureRandom.defaultRandom.nextInt(256),
    );
    final hash = await _passwordHasher.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    await _database.insertUser(
      name: cleanName,
      email: cleanEmail,
      passwordSalt: base64Encode(salt),
      passwordHash: base64Encode(await hash.extractBytes()),
    );
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_isValidEmail(cleanEmail) || password.isEmpty) {
      throw const AuthException('Enter your email and password.');
    }

    final row = await _database.getUserByEmail(cleanEmail);
    if (row == null) {
      throw const AuthException('Incorrect email or password.');
    }

    final salt = base64Decode(row['password_salt'] as String);
    final expectedHash = base64Decode(row['password_hash'] as String);
    final actualHash = await _passwordHasher.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    if (!_constantTimeEquals(await actualHash.extractBytes(), expectedHash)) {
      throw const AuthException('Incorrect email or password.');
    }

    final user = AuthUser.fromMap(row);
    final sessionInstanceId = _newSessionInstanceId();
    await _preferences.setInt(_sessionUserIdKey, user.id);
    await _preferences.setString(_sessionInstanceIdKey, sessionInstanceId);
    try {
      await _database.recordActivity(
        userId: user.id,
        eventType: 'login_succeeded',
        dedupeKey: 'login:${user.id}:$sessionInstanceId',
      );
    } catch (_) {
      await _preferences.remove(_sessionUserIdKey);
      await _preferences.remove(_sessionInstanceIdKey);
      rethrow;
    }
    return user;
  }

  Future<AdminDashboardData> loadAdminDashboard() async {
    final userId = await _preferences.getInt(_sessionUserIdKey);
    if (userId == null) {
      throw const AuthException('Sign in with an administrator account.');
    }

    final currentUser = await _database.getUserById(userId);
    if (currentUser == null || currentUser['role'] != 'ADMIN') {
      throw const AuthException('You are not authorized to view this page.');
    }

    final rows = await _database.getAdminDashboardUsers();
    return AdminDashboardData(
      users: rows.map(AdminDashboardUser.fromMap).toList(),
      calculations: (await _database.getAdminCalculationRows())
          .map(AdminDashboardCalculation.fromMap)
          .toList(),
      activities: await _database.getAdminActivityRows(),
      userCount: await _database.getUserCount(),
      adminCount: await _database.getAdminCount(),
      calculationCount: await _database.getCalculationCount(),
      activityCount: await _database.getActivityCount(),
      totalEmissions: await _database.getTotalEmissions(),
      databaseAccessible: true,
    );
  }

  Future<bool> canSetUpFirstAdmin() async {
    if (!kDebugMode) return false;
    final userId = await _preferences.getInt(_sessionUserIdKey);
    return userId != null && !await _database.hasAdministrator();
  }

  Future<AuthUser> setUpFirstAdmin() async {
    if (!kDebugMode) {
      throw const AuthException(
        'Initial administrator setup is available only in debug builds.',
      );
    }

    final userId = await _preferences.getInt(_sessionUserIdKey);
    if (userId == null) {
      throw const AuthException('Sign in before setting up an administrator.');
    }
    if (!await _database.promoteFirstAdmin(userId)) {
      throw const AuthException(
        'The first administrator could not be set up. An administrator may already exist.',
      );
    }

    final row = await _database.getUserById(userId);
    if (row == null || row['role'] != 'ADMIN') {
      throw const AuthException('Unable to verify the administrator account.');
    }
    return AuthUser.fromMap(row);
  }

  Future<void> signOut() async {
    final userId = await _preferences.getInt(_sessionUserIdKey);
    final sessionInstanceId =
        await _preferences.getString(_sessionInstanceIdKey) ??
        _newSessionInstanceId();
    try {
      if (userId != null) {
        await _database.recordActivity(
          userId: userId,
          eventType: 'logout',
          dedupeKey: 'logout:$userId:$sessionInstanceId',
        );
      }
    } finally {
      await _preferences.remove(_sessionUserIdKey);
      await _preferences.remove(_sessionInstanceIdKey);
    }
  }

  String _newSessionInstanceId() =>
      DateTime.now().toUtc().microsecondsSinceEpoch.toString();

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
