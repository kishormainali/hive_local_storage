import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hive_local_storage/src/_crypto/aes_gcm_cipher.dart';
import 'package:synchronized/synchronized.dart';

import '_session_adaptor.dart';
import 'secure_storage.dart';
import 'token.dart';

/// {@template local_storage}
/// A wrapper class for session and cache box uses [Hive]
/// {@endtemplate}
class LocalStorage {
  /// Example: use with Riverpod
  ///
  /// ```dart
  /// final localStorageProvider = Provider<LocalStorage>((ref)=>throw UnImplementedError());
  /// ```
  ///
  /// in main function
  ///
  ///```dart
  /// void main() {
  ///   runZonedGuarded(
  ///     () async {
  ///       await LocalStorage.initialize(// options);
  ///       runApp(
  ///         ProviderScope(
  ///           overrides: [
  ///             localStorageProvider.overrideWithValue(LocalStorage()),
  /// or
  ///             localStorageProvider.overrideWithValue(LocalStorage.instance),
  ///           ],
  ///           child: App(),
  ///         ),
  ///       );
  ///     },
  ///     (e, _) => throw e,
  ///   );
  /// }
  /// ```

  ///
  ///
  ///{@macro local_storage}
  LocalStorage._();

  /// singleton instance
  static LocalStorage? _instance;

  /// returns the singleton instance of [LocalStorage]
  static LocalStorage get instance {
    if (_instance == null) {
      throw Exception(
        'LocalStorage is not initialized. Please call initialize() first.',
      );
    }
    return _instance!;
  }

  /// returns the singleton instance of [LocalStorage]
  /// shorthand for [instance]
  static LocalStorage get i => instance;

  /// returns the singleton instance of [LocalStorage]
  factory LocalStorage() => instance;

  /// lock for synchronizing access
  static final _lock = Lock();

  /// session box key
  static const String sessionKey = '__JWT_SESSION_KEY__';

  // session item key
  static const String sessionItemKey = '__JWT_SESSION_ITEM_KEY__';

  /// cache key
  static const String cacheKey = '__CACHE_KEY__';

  /// encryption key
  static const String encryptionBoxKey = '__ENCRYPTION_KEY__';

  /// [Box] _cacheBox
  static late Box<dynamic> _cacheBox;

  /// opened boxes
  static final Set<String> _openedBoxes = {};

  /// initialize the dependencies
  /// register the adapters
  /// ```
  /// await LocalStorage.initialize(registerAdapters:Hive.registerAdapters);
  /// ```
  /// open the boxes
  /// returns [LocalStorage] instance
  static Future<void> initialize({
    void Function()? registerAdapters,
    HiveCipher? customCipher,
    String? storageDirectory,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    await _lock.synchronized(() async {
      await Hive.initFlutter(storageDirectory);

      // migrate session to token storage if needed
      if (await Hive.boxExists(sessionKey)) {
        _migrateToTokenStorageIfNeeded(customCipher);
      }

      // register adapters
      registerAdapters?.call();

      try {
        // open cache box
        _cacheBox = await Hive.openBox(
          cacheKey,
          encryptionCipher: await _cipher(customCipher),
        );
      } catch (_) {
        dev.log(
          'Error opening cache box clearing all the caches and re-initializing...',
        );
        // in case of any error, delete the box and recreate it
        await Hive.deleteBoxFromDisk(cacheKey);
        _cacheBox = await Hive.openBox(
          cacheKey,
          encryptionCipher: await _cipher(customCipher),
        );
      }
    });

    _instance ??= LocalStorage._();
  }

  /// migrate existing session to token storage
  /// this is a one-time migration
  static Future<void> _migrateToTokenStorageIfNeeded(
    HiveCipher? customCipher,
  ) async {
    try {
      Hive.registerAdapter(SessionAdapter());
      final sessionBox = await Hive.openBox<Session>(
        sessionKey,
        encryptionCipher: await _cipher(customCipher),
      );
      final session = sessionBox.get(sessionItemKey);
      if (session != null) {
        dev.log('Old session detected, migrating  to secure token storage...');
        final token = AuthToken(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          createdAt: session.createdAt,
          updatedAt: session.updatedAt,
        );
        await SecureStorage.i.setToken(token);
      }
      dev.log('cleaning old token storage...');
      await sessionBox.clear();
      await sessionBox.deleteFromDisk();
    } on PlatformException catch (_) {
      dev.log('Error during migration removing all the old sessions....:');
      await Hive.deleteBoxFromDisk(sessionKey);
    }
  }

  /// returns encryption cipher for boxes
  static Future<HiveCipher> _cipher(HiveCipher? customCipher) async {
    if (customCipher != null) return customCipher;
    return await _encryptionCipher;
  }

  /// HiveAesCipher encryptionKey
  /// encryption key to secure session box
  static Future<HiveCipher> get _encryptionCipher async {
    try {
      late Uint8List encryptionKey;
      var keyString = await SecureStorage.i.get(encryptionBoxKey);
      encryptionKey = keyString == null
          ? await __newEncryptionCipher
          : base64Url.decode(keyString);
      return AesGcmCipher(encryptionKey);
    } on PlatformException catch (_) {
      dev.log('Error getting encryption cipher, generating new one...');
      await SecureStorage.i.delete(encryptionBoxKey);
      return AesGcmCipher(await __newEncryptionCipher);
    }
  }

  /// Generate new encryption key
  static Future<Uint8List> get __newEncryptionCipher async {
    final newKey = Hive.generateSecureKey();
    await SecureStorage.i.set(encryptionBoxKey, base64UrlEncode(newKey));
    return Uint8List.fromList(newKey);
  }

  /// `openBox`
  /// open custom box
  FutureOr<Box<T>> openBox<T>({
    required String boxName,
    HiveCipher? customCipher,
    int? typeId,
  }) async {
    if (typeId != null && !Hive.isAdapterRegistered(typeId)) {
      throw Exception('Please register adapter for $T.');
    }
    return await _lock.synchronized(() async {
      _openedBoxes.add(boxName);
      return Hive.openBox<T>(
        boxName,
        encryptionCipher: await _cipher(customCipher),
      );
    });
  }

  /// `getBox`
  /// returns the previously opened box
  Future<Box<T>> getBox<T>(String name) async {
    if (Hive.isBoxOpen(name) && (await Hive.boxExists(name))) {
      return Hive.box<T>(name);
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `put`
  /// puts data in cache box
  /// if [boxName] is provided then it will put data in custom box
  Future<void> put<T>({
    required String key,
    required T value,
    String? boxName,
  }) async {
    if (boxName != null) {
      if (Hive.isBoxOpen(boxName)) {
        await _lock.synchronized(() {
          final box = Hive.box<T>(boxName);
          return box.put(key, value);
        });
      } else {
        throw Exception('Please `openBox` before accessing it');
      }
    } else {
      await _lock.synchronized(() => _cacheBox.put(key, value));
    }
  }

  /// `get`
  /// get data from cache box
  /// returns [defaultValue] if [key] is not found
  /// returns null if [defaultValue] is not provided
  /// if [boxName] is provided then it will get data from custom box
  T? get<T>({required String key, T? defaultValue, String? boxName}) {
    if (boxName != null) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<T>(boxName);
        return box.get(key, defaultValue: defaultValue);
      } else {
        throw Exception('Please `openBox` before accessing it');
      }
    } else {
      return _cacheBox.get(key, defaultValue: defaultValue);
    }
  }

  /// `remove`
  /// removes data from cache box
  /// if [boxName] is provided then it will remove data from custom box
  Future<void> remove<T>({required String key, String? boxName}) async {
    if (boxName != null) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<T>(boxName);
        await _lock.synchronized(() => box.delete(key));
      } else {
        throw Exception('Please `openBox` before accessing it');
      }
    } else {
      await _lock.synchronized(() => _cacheBox.delete(key));
    }
  }

  /// `values`
  /// get all the values from custom box
  List<T> values<T>(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      return box.values.toList();
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `add`
  /// add data to custom box
  Future<void> add<T>({required String boxName, required T value}) async {
    if (Hive.isBoxOpen(boxName)) {
      await _lock.synchronized(() {
        final box = Hive.box<T>(boxName);
        return box.add(value);
      });
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `addAll`
  /// add multiple data to custom box
  Future<void> addAll<T>({
    required String boxName,
    required List<T> values,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      await _lock.synchronized(() {
        final box = Hive.box<T>(boxName);
        return box.addAll(values);
      });
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `update`
  /// update item from data
  ///
  /// only supports [HiveObject] type
  Future<void> update<T extends HiveObject>({
    required String boxName,
    required T value,
    bool Function(T)? filter,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      final data = box.values.firstWhereOrNull(
        filter ?? (element) => element == value,
      );
      if (data != null) await _lock.synchronized(() => data.delete());
      await _lock.synchronized(() => box.add(value));
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `delete`
  /// delete item from data
  ///
  /// only supports [HiveObject] type
  Future<void> delete<T extends HiveObject>({
    required String boxName,
    required T value,
    bool Function(T)? filter,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      final data = box.values.firstWhereOrNull(
        filter ?? (element) => element == value,
      );
      await _lock.synchronized(() => data?.delete());
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// private getter to access session
  Future<AuthToken?> get token => SecureStorage.i.getToken();

  /// refreshToken
  /// getter to access accessToken
  Future<String?> get accessToken async => SecureStorage.i.accessToken;

  /// refreshToken
  /// getter to access refreshToken
  Future<String?> get refreshToken async => SecureStorage.i.refreshToken;

  /// createdAt
  /// getter to access createdAt
  Future<DateTime?> get createdAt async => (await token)?.createdAt;

  /// updatedAt
  /// getter to access updatedAt
  Future<DateTime?> get updatedAt async => (await token)?.updatedAt;

  /// `onSessionChange`
  /// returns stream of [bool] when data changes on box
  @Deprecated('Use onTokenChange instead')
  Stream<bool> get onSessionChange => SecureStorage.i.onTokenChange;

  /// `hasSession`
  /// checks whether `Box<Session>` is not empty or [Session] is not null
  @Deprecated('Use hasToken instead')
  Future<bool> get hasSession => hasToken;

  /// `hasToken`
  /// checks whether `AuthToken` is not null
  Future<bool> get hasToken => SecureStorage.i.hasToken;

  /// `onTokenChange`
  /// returns stream of [bool] when data changes on token
  Stream<bool> get onTokenChange => SecureStorage.i.onTokenChange;

  /// `saveToken`
  /// updates access token if exists or saves new one if not
  /// updates refresh token
  Future<void> saveToken(String token, [String? refreshToken]) async {
    _lock.synchronized(() async {
      return SecureStorage.i.setToken(
        AuthToken(accessToken: token, refreshToken: refreshToken),
      );
    });
  }

  /// `isTokenExpired`
  /// checks whether token is expired or not
  Future<bool?> get isTokenExpired async {
    final token = await this.token;
    if (token == null) return null;
    return token.isAccessTokenExpired;
  }

  /// clearSession
  /// removes the [Token] value from SecureStorage
  Future<void> clearSession() async {
    await _lock.synchronized(SecureStorage.i.deleteToken);
  }

  /// watchKey
  /// watch specific key for value changed
  Stream<T?> watchKey<T>({required String key, String? boxName}) {
    if (boxName != null) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<T>(boxName);
        return box.watch(key: key).map<T?>((event) {
          if (event.deleted) return null;
          return event.value as T?;
        });
      } else {
        throw Exception(
          '$boxName is not yet opened, Please `openBox` before accessing it',
        );
      }
    } else {
      return _cacheBox.watch(key: key).map<T?>((event) {
        if (event.deleted) return null;
        return event.value as T?;
      });
    }
  }

  /// getList
  /// get list data
  List<T> getList<T>({required String key, List<T> defaultValue = const []}) {
    try {
      final String encodedData = _cacheBox.get(key, defaultValue: '');
      if (encodedData.isEmpty) return defaultValue;
      final decodedData = jsonDecode(_cacheBox.get(key));
      return List<T>.of(decodedData);
    } catch (_) {
      return defaultValue;
    }
  }

  /// save list of data
  Future<void> putList<T>({required String key, required List<T> value}) async {
    final encodedData = jsonEncode(value);
    return _cacheBox.put(key, encodedData);
  }

  /// save
  /// puts value in box with [key]
  Future<void> putAll({required Map<String, dynamic> entries}) async {
    return _cacheBox.putAll(entries);
  }

  /// clear
  /// clear all values from opened boxes including cache box
  Future<int> clear() async {
    return _lock.synchronized(() async {
      await Future.wait([
        _cacheBox.clear(),
        for (final boxName in _openedBoxes)
          if (Hive.isBoxOpen(boxName)) Hive.box(boxName).clear(),
      ]);
      return 0;
    });
  }

  /// `writeAndClose`
  /// write value to box and close the box
  static Future<void> writeAndClose<T>({
    required String boxName,
    required String key,
    required T value,
  }) async {
    return _lock.synchronized(() async {
      /// open new box
      final box = await Hive.openBox<T>(
        boxName,
        encryptionCipher: await _cipher(null),
      );

      /// put value
      await box.put(key, value);

      /// close the box
      await box.close();
    });
  }

  /// `readAndClose`
  /// read value from box and close the box
  static Future<T?> readAndClose<T>({
    required String key,
    required String boxName,
  }) async {
    return _lock.synchronized(() async {
      /// open new box
      final box = await Hive.openBox<T>(
        boxName,
        encryptionCipher: await _cipher(null),
      );
      final value = box.get(key);

      /// close the box
      await box.close();

      /// return value
      return value;
    });
  }

  /// clearAll
  /// clear all values from  cache box
  /// clears all boxes created using `openBox()`
  /// also clears token/session storage
  Future<void> clearAll() async {
    return _lock.synchronized(() async {
      final futures = <Future>[];
      if (_openedBoxes.isNotEmpty) {
        for (var boxName in _openedBoxes) {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            futures.add(box.clear());
          }
        }
      }
      await Future.wait([
        SecureStorage.i.deleteToken(),
        SecureStorage.i.clear(),
        _cacheBox.clear(),
        ...futures,
      ]);
    });
  }

  /// close all the opened box and clear token storage
  Future<void> closeAll() async {
    await _lock.synchronized(() {
      _openedBoxes.clear();
      return Future.wait([
        SecureStorage.i.clear(),
        _cacheBox.close(),
        Hive.close(),
      ]);
    });
  }

  /// delete all the opened box
  Future<void> deleteAll() async {
    await _lock.synchronized(() {
      _openedBoxes.clear();
      return Future.wait([_cacheBox.deleteFromDisk(), Hive.deleteFromDisk()]);
    });
  }

  /// convert box to map
  Map<String, Map<String, dynamic>?> toCacheMap() => Map.unmodifiable({
    "cache": _cacheBox.toMap(),
    for (var boxName in _openedBoxes)
      if (Hive.isBoxOpen(boxName)) boxName: Hive.box(boxName).toMap(),
  });
}
