/*
 * Copyright (c) 2025.
 * Author: Kishor Mainali
 *
 */

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Internal helper around [FlutterSecureStorage] used only to persist the
/// Hive box encryption key. Not exported as part of the public API.
class SecureStorage {
  /// singleton instance
  factory SecureStorage() => _instance;

  SecureStorage._() {
    _storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: AndroidOptions(),
    );
  }

  /// singleton instance of secure storage
  static final SecureStorage _instance = SecureStorage._();

  /// singleton instance getter
  static SecureStorage get instance => _instance;

  /// singleton instance getter for shortcut
  static SecureStorage get i => _instance;

  /// secure storage instance
  late final FlutterSecureStorage _storage;

  /// set the value
  Future<void> set(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// get the value
  Future<String?> get(String key) async {
    return _storage.read(key: key);
  }

  /// delete the value
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
