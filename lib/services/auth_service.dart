import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';

class AuthUser {
  const AuthUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  factory AuthUser.fromMap(Map<String, Object?> row) => AuthUser(
    id: row['id'] as int,
    name: row['name'] as String,
    email: row['email'] as String,
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
      await signOut();
      return null;
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
    await _preferences.setInt(_sessionUserIdKey, user.id);
    return user;
  }

  Future<void> signOut() => _preferences.remove(_sessionUserIdKey);

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