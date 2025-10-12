import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as fss;

/// A minimal storage interface used by AuthService so tests can supply an
/// in-memory implementation without needing the full flutter_secure_storage API.
abstract class SecureStorageInterface {
  Future<void> write({required String key, required String? value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

class FlutterSecureStorageAdapter implements SecureStorageInterface {
  final fss.FlutterSecureStorage _inner;
  const FlutterSecureStorageAdapter([fss.FlutterSecureStorage? inner]) : _inner = inner ?? const fss.FlutterSecureStorage();
  @override
  Future<void> write({required String key, required String? value}) => _inner.write(key: key, value: value);
  @override
  Future<String?> read({required String key}) => _inner.read(key: key);
  @override
  Future<void> delete({required String key}) => _inner.delete(key: key);
  @override
  Future<void> deleteAll() => _inner.deleteAll();
}

class AuthService {
  final SecureStorageInterface _storage;

  static const _kTokenKey = 'auth_token';
  static const _kUsernameKey = 'auth_username';

  AuthService({SecureStorageInterface? storage}) : _storage = storage ?? const FlutterSecureStorageAdapter();

  /// Simulate login against an API. Replace this with real HTTP calls.
  Future<String> login(String username, String password) async {
    // Basic validation
    if (username.trim().isEmpty || password.isEmpty) {
      throw AuthException('Invalid credentials');
    }

    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 500));

    // In a real implementation you would POST username/password and receive a token.
    // We'll generate a fake token payload with expiry in 1 day.
    final expiry = DateTime.now().add(const Duration(days: 1)).toIso8601String();
    final token = base64Url.encode(utf8.encode(jsonEncode({'user': username, 'exp': expiry}))); 

    await _storage.write(key: _kTokenKey, value: token);
    await _storage.write(key: _kUsernameKey, value: username);
    return token;
  }

  Future<String> register(String username, String password) async {
    // Simulate account creation
    if (username.trim().isEmpty || password.length < 4) throw AuthException('Invalid registration');
    await Future.delayed(const Duration(milliseconds: 600));
    // Reuse login behavior to create token
    return login(username, password);
  }

  Future<void> logout() async {
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kUsernameKey);
  }

  Future<String?> token() async => await _storage.read(key: _kTokenKey);

  Future<String?> username() async => await _storage.read(key: _kUsernameKey);

  /// Simple expiry check based on token payload. Returns true if token exists and not expired.
  Future<bool> isAuthenticated() async {
    final t = await token();
    if (t == null) return false;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(t)));
      final exp = DateTime.parse(payload['exp'] as String);
      return DateTime.now().isBefore(exp);
    } catch (e) {
      return false;
    }
  }

  /// For tests: clear all storage
  @visibleForTesting
  Future<void> clearAll() async => await _storage.deleteAll();
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}
