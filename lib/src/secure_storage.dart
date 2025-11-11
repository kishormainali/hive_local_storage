/*
 * Copyright (c) 2025.
 * Author: Kishor Mainali
 *
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_local_storage/src/jwt_decoder.dart';
import 'package:rxdart/rxdart.dart';

import 'token.dart';

///{@template token_storage}
/// A class that stores and retrieves the access token and refresh token.
/// The access token is stored in the secure storage.
/// The refresh token is stored in the secure storage.
/// {@endtemplate}
class SecureStorage {
  /// {@macro token_storage}
  /// singleton instance
  factory SecureStorage() => _instance;

  ///{@macro token_storage}
  SecureStorage._() {
    _storage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
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

  /// access token key
  static const _accessTokenKey = '__accessToken__';

  /// refresh token key
  static const _refreshTokenKey = '__refresh__';

  final BehaviorSubject<bool> _accessTokenSubject = BehaviorSubject<bool>();

  /// register accessToken listener
  void registerAccessTokenListener(ValueChanged<String?> listener) {
    _storage.registerListener(
      key: _accessTokenKey,
      listener: (token) {
        listener(token);
        _accessTokenSubject.add(token != null);
      },
    );
  }

  /// unregister accessToken listener
  void unregisterAccessTokenListener() {
    _storage.unregisterAllListenersForKey(key: _accessTokenKey);
    _accessTokenSubject.close();
  }

  /// register listener
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {
    _storage.registerListener(key: key, listener: listener);
  }

  /// unregister listener for all keys
  void unregisterListener(String key) {
    _storage.unregisterAllListenersForKey(key: key);
  }

  /// save the auth token
  Future<void> setToken(AuthToken token) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: token.accessToken),
      if (token.refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: token.refreshToken!),
    ]);
  }

  /// get the auth token
  Future<AuthToken?> getToken() async {
    final accessToken = await this.accessToken;
    final refreshToken = await this.refreshToken;
    if (accessToken == null) return null;
    return AuthToken(accessToken: accessToken, refreshToken: refreshToken);
  }

  /// get access token
  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  /// get refresh token
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  /// check if session exists
  Future<bool> get hasToken async {
    final token = await accessToken;
    return token != null && JwtDecoder.isExpired(token) == false;
  }

  /// delete the session
  Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// set the value
  Future<void> set(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// get the value
  Future<String?> get(String key) async {
    return _storage.read(key: key);
  }

  /// get all values
  Future<Map<String, String>> getAll() async {
    return _storage.readAll();
  }

  /// delete the value
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// clear storage
  Future<void> clear() => _storage.deleteAll();

  @mustCallSuper
  void dispose() {
    unregisterAccessTokenListener();
    _storage.unregisterAllListeners();
  }
}
