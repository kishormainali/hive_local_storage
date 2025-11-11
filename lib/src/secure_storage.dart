/*
 * Copyright (c) 2025.
 * Author: Kishor Mainali
 *
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    // register access token listener
    _storage.registerListener(
      key: _accessTokenKey,
      listener: (token) {
        bool isValid = token != null;
        _accessTokenSubject.add(isValid);
      },
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

  /// access token subject
  final BehaviorSubject<bool> _accessTokenSubject =
      BehaviorSubject<bool>.seeded(false);

  /// register accessToken listener
  void registerAccessTokenListener(ValueChanged<String?> listener) {
    _storage.registerListener(key: _accessTokenKey, listener: listener);
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
    return token != null;
  }

  /// delete the session
  /// deletes both access token and refresh token
  Future<void> deleteToken() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// `onTokenChange`
  /// returns stream of [bool] when data changes on token
  Stream<bool> get onTokenChange async* {
    // check current token status
    final token = await hasToken;
    // add the current status to the stream
    _accessTokenSubject.add(token);
    // Then forward all events from the token subject
    yield* _accessTokenSubject.stream;
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
