import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'jwt_decoder.dart';
import 'session.dart';
import 'storage_keys.dart';

/// {@template local_storage}
/// A wrapper class for session and cache box uses [Hive]
/// {@endtemplate}
class LocalStorage {
  ///{@macro local_storage}
  LocalStorage._();

  /// [FlutterSecureStorage] storage for storing encryption key
  static late FlutterSecureStorage _storage;

  /// [Box] session box
  static late Box<Session> _sessionBox;

  /// [Box] encrypted box
  static late Box<dynamic> _encryptedBox;

  /// [Box] _cacheBox
  static late Box<dynamic> _cacheBox;

  /// init
  /// initialize the dependencies
  /// register the adapters
  /// open the boxes
  /// returns [LocalStorage] instance
  static Future<LocalStorage> getInstance(
      [List<TypeAdapter<HiveObject>>? adapters]) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (adapters != null && adapters.isNotEmpty) {
      for (final adapter in adapters) {
        Hive.registerAdapter(adapter);
      }
    }
    Hive.registerAdapter(SessionAdapter());
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    );
    final encryptionCipher = await _encryptionKey;
    await Hive.initFlutter();
    _sessionBox = await Hive.openBox<Session>(
      StorageKeys.sessionKey,
      encryptionCipher: encryptionCipher,
    );
    _encryptedBox = await Hive.openBox<dynamic>(
      StorageKeys.encryptedBoxKey,
      encryptionCipher: encryptionCipher,
    );
    _cacheBox = await Hive.openBox<dynamic>(StorageKeys.cacheKey);
    return LocalStorage._();
  }

  /// HiveAesCipher encryptionKey
  /// encryption key to secure session box
  static Future<HiveAesCipher> get _encryptionKey async {
    late Uint8List encryptionKey;
    var keyString = await _storage.read(key: StorageKeys.encryptionKey);
    if (keyString == null) {
      final key = Hive.generateSecureKey();
      await _storage.write(
          key: StorageKeys.encryptionKey, value: base64UrlEncode(key));
      encryptionKey = Uint8List.fromList(key);
    } else {
      encryptionKey = base64Url.decode(keyString);
    }
    return HiveAesCipher(encryptionKey);
  }

  /// `getSession`
  /// get [Session] from the box
  Session? getSession() {
    return _sessionBox.isNotEmpty ? _sessionBox.getAt(0) : null;
  }

  /// `hasSession`
  /// checks whether `Box<Session>` is not empty or [Session] is not null
  bool get hasSession {
    return _sessionBox.isNotEmpty && _sessionBox.getAt(0) != null;
  }

  /// `saveSession`
  /// clears the previously stored value and adds new [Session]
  Future<void> saveSession(Session session) async {
    await _sessionBox.clear();
    await _sessionBox.add(session);
    return Future.value();
  }

  /// `isTokenExpired`
  /// checks whether token is expired or not
  bool get isTokenExpired {
    if (_sessionBox.isEmpty) return true;
    final session = _sessionBox.getAt(0)!;
    return JwtDecoder.isExpired(session.accessToken);
  }

  /// clearSession
  /// removes the [Session] value from [Box]
  Future<void> clearSession() async {
    _sessionBox.clear();
    return Future.value();
  }

  /// get
  /// get value from box associated with [key]
  T? get<T>({
    required String key,
    T? defaultValue,
    bool useEncryption = false,
  }) {
    if (useEncryption) {
      return _encryptedBox.get(key, defaultValue: defaultValue);
    } else {
      return _cacheBox.get(key, defaultValue: defaultValue);
    }
  }

  /// save
  /// puts value in box with [key]
  Future<void> put<T>({
    required String key,
    required T value,
    bool useEncryption = false,
  }) async {
    if (useEncryption) {
      return _encryptedBox.put(key, value);
    } else {
      return _cacheBox.put(key, value);
    }
  }

  /// save
  /// puts value in box with [key]
  Future<void> putAll({
    required Map<String, dynamic> entries,
    bool useEncryption = false,
  }) async {
    if (useEncryption) {
      return _encryptedBox.putAll(entries);
    } else {
      return _cacheBox.putAll(entries);
    }
  }

  /// remove
  /// removes value from box registered with [key]
  Future<void> remove({
    required String key,
    bool useEncryption = false,
  }) async {
    if (useEncryption) {
      return _encryptedBox.delete(key);
    } else {
      return _cacheBox.delete(key);
    }
  }

  /// clear
  /// clear all values from box
  Future<int> clear({bool useEncryption = false}) async {
    if (useEncryption) {
      return _encryptedBox.clear();
    } else {
      return _cacheBox.clear();
    }
  }

  /// close all the opened box
  Future<void> closeAll() async {
    await Future.wait([
      _sessionBox.close(),
      _encryptedBox.close(),
      _cacheBox.close(),
    ]);
  }

  /// convert box to map
  Map<String, Map<String, dynamic>?> toCacheMap() =>
      Map.unmodifiable(_cacheBox.toMap());

  /// convert box to map
  Map<String, Map<String, dynamic>?> toEncryptedMap() =>
      Map.unmodifiable(_encryptedBox.toMap());
}
