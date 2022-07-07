import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  static late Box<dynamic> _encryptedBox;

  /// [Box] _cacheBox
  static late Box<dynamic> _cacheBox;

  /// init
  /// initialize the dependencies
  /// register the adapters
  /// open the boxes
  /// returns [LocalStorage] instance
  static Future<LocalStorage> getInstance() async {
    WidgetsFlutterBinding.ensureInitialized();
    Hive.registerAdapter(SessionAdapter());
    _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true));
    final encryptionCipher = await _encryptionKey;
    await Hive.initFlutter();
    _encryptedBox = await Hive.openBox<dynamic>(StorageKeys.sessionKey,
        encryptionCipher: encryptionCipher);
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

  /// getSession
  /// get [Session] from the box
  Future<Session?> getSession() async {
    return _encryptedBox.get(StorageKeys.sessionKey) as Session?;
  }

  /// hasSession
  /// checks whether [Session] is not null or [Session.accessToken] is not empty
  FutureOr<bool> hasSession() async {
    final session = await getSession();
    return session != null && session.accessToken.isNotEmpty;
  }

  /// saveSession
  /// clears the previously stored value and adds new [Session]
  FutureOr<void> saveSession(Session session) async {
    await _encryptedBox.delete(StorageKeys.sessionKey);
    await _encryptedBox.put(StorageKeys.sessionKey, session);
    return Future.value();
  }

  /// clearSession
  /// removes the [Session] value from [Box]
  FutureOr<void> clearSession() async {
    return _encryptedBox.delete(StorageKeys.sessionKey);
  }

  /// getEncrypted
  /// gets the value from encrypted box associated with [key]
  FutureOr<T?> getEncrypted<T>(String key) async {
    return _encryptedBox.get(key) as T?;
  }

  /// saveEncrypted
  /// stores the value in encrypted box
  FutureOr<void> saveEncrypted<T>(String key, T value) async {
    return _encryptedBox.put(key, value);
  }

  /// removeEncrypted
  /// deletes the value from encrypted box
  FutureOr<void> removeEncrypted(String key) async {
    return _encryptedBox.delete(key);
  }

  /// clearEncrypted
  /// clears the encrypted box
  FutureOr<int> clearEncrypted() async {
    return _encryptedBox.clear();
  }

  /// get
  /// get value from box associated with [key]
  Future<T?> get<T>(String key) async {
    return _cacheBox.get(key) as T?;
  }

  /// save
  /// puts [value] in box with [key]
  FutureOr<void> save<T>(String key, T value) async {
    return _cacheBox.put(key, value);
  }

  /// remove
  /// removes value from box registered with [key]
  FutureOr<void> remove(String key) async {
    return _cacheBox.delete(key);
  }

  /// clear
  /// clear all values from box
  FutureOr<int> clear() async {
    return _cacheBox.clear();
  }
}
