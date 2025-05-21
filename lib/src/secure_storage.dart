import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_local_storage/src/auth_token.dart';
import 'package:rxdart/rxdart.dart';

class SecureStorage {
  SecureStorage._() {
    _flutterSecureStorage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
    );
    _flutterSecureStorage.registerListener(
      key: _tokenKey,
      listener: (value) {
        try {
          if (value == null) _tokenSubject.sink.add(null);
          final map = jsonDecode(value!) as Map<String, dynamic>;
          final token = AuthToken.fromJson(map);
          _tokenSubject.add(token);
        } catch (_) {
          _tokenSubject.sink.add(null);
        }
      },
    );
  }

  /// key for the token
  final _tokenKey = '___TOKEN_KEY___';

  /// factory
  factory SecureStorage() => SecureStorage._();

  /// secure storage instance
  late final FlutterSecureStorage _flutterSecureStorage;

  /// token subject
  final BehaviorSubject<AuthToken?> _tokenSubject = BehaviorSubject.seeded(
    null,
  );

  /// token stream
  Stream<AuthToken?> get tokenStream => _tokenSubject.stream;

  /// saves token
  Future<void> saveToken(AuthToken token) async {
    return _flutterSecureStorage.write(
      key: _tokenKey,
      value: jsonEncode(token.toJson()),
    );
  }

  /// gets saved token
  Future<AuthToken?> getToken() async {
    try {
      final value = await _flutterSecureStorage.read(key: _tokenKey);
      if (value == null) return null;
      final map = jsonEncode(value) as Map<String, dynamic>;
      return AuthToken.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// checks weather token is not null
  Future<bool> get hasToken async {
    return await getToken() != null;
  }

  /// delete token
  Future<void> deleteToken() async {
    return _flutterSecureStorage.delete(key: _tokenKey);
  }

  /// save to secure storage
  Future<void> save({required String key, required String value}) {
    return _flutterSecureStorage.write(key: key, value: value);
  }

  /// get from secure storage
  Future<String?> get(String key, [String? defaultValue]) async {
    final value = await _flutterSecureStorage.read(key: key);
    return value ?? defaultValue;
  }

  /// deletes from secure storage
  Future<void> delete(String key) {
    return _flutterSecureStorage.delete(key: key);
  }

  /// register listener for value changes for key
  void registerListener({
    required String key,
    required void Function(String?) listener,
  }) {
    return _flutterSecureStorage.registerListener(key: key, listener: listener);
  }

  /// unregister all listeners for key
  void unregisterListener(String key) {
    return _flutterSecureStorage.unregisterAllListenersForKey(key: key);
  }

  /// dispose
  @mustCallSuper
  Future<void> dispose() async {
    await _tokenSubject.close();
    _flutterSecureStorage.unregisterAllListenersForKey(key: _tokenKey);
  }
}
