import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

import 'jwt_decoder.dart';
import 'session.dart';

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
  ///       final localStorage = await LocalStorage.getInstance();
  ///       runApp(
  ///         ProviderScope(
  ///           overrides: [
  ///             localStorageProvider.overrideWithValue(localStorage),
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

  static final _lock = Lock();

  /// session key
  static const String sessionKey = '__JWT_SESSION_KEY__';

  /// cache key
  static const String cacheKey = '__CACHE_KEY__';

  /// encryption key
  static const String encryptionBoxKey = '__ENCRYPTION_KEY__';

  /// [FlutterSecureStorage] storage for storing encryption key
  static late FlutterSecureStorage _storage;

  /// [Box] session box
  static late Box<Session> _sessionBox;

  /// [Box] _cacheBox
  static late Box<dynamic> _cacheBox;

  /// initialize the dependencies
  /// register the adapters
  /// ```
  /// final instance = LocalStorage.getInstance(registerAdapters:(){
  ///   Hive..registerAdapter(adapter1)
  ///       ..registerAdapter(adapter2);
  /// });
  /// ```
  /// open the boxes
  /// returns [LocalStorage] instance
  static Future<LocalStorage> getInstance({
    void Function()? registerAdapters,
    HiveCipher? customCipher,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    await _lock.synchronized(() async {
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
      );
      await Hive.initFlutter();
      Hive.registerAdapter(SessionAdapter());
      registerAdapters?.call();
      _sessionBox = await Hive.openBox<Session>(sessionKey,
          encryptionCipher: await _cipher(customCipher));
      _cacheBox = await Hive.openBox(cacheKey,
          encryptionCipher: await _cipher(customCipher));
    });
    return LocalStorage._();
  }

  /// returns encryption cipher for boxes
  static Future<HiveCipher> _cipher(HiveCipher? customCipher) async {
    if (customCipher != null) return customCipher;
    return await _encryptionKey;
  }

  /// HiveAesCipher encryptionKey
  /// encryption key to secure session box
  static Future<HiveAesCipher> get _encryptionKey async {
    late Uint8List encryptionKey;
    var keyString = await _storage.read(key: encryptionBoxKey);
    if (keyString == null) {
      final key = Hive.generateSecureKey();
      await _storage.write(key: encryptionBoxKey, value: base64UrlEncode(key));
      encryptionKey = Uint8List.fromList(key);
    } else {
      encryptionKey = base64Url.decode(keyString);
    }
    return HiveAesCipher(encryptionKey);
  }

  /// `openCustomBox`
  /// open custom box
  Future<void> openBox<T>({
    required String boxName,
    HiveCipher? customCipher,
    int? typeId,
  }) async {
    if (typeId != null && !Hive.isAdapterRegistered(typeId)) {
      throw Exception('Please register adapter for $T');
    }
    await _lock.synchronized(
      () async => Hive.openBox<T>(
        boxName,
        encryptionCipher: await _cipher(customCipher),
      ),
    );
  }

  /// `getCustomList`
  /// get data from custom box
  List<T> getBoxValues<T extends HiveObject>({
    required String boxName,
  }) {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      return box.values.toList();
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `add`
  /// add data to custom box
  Future<void> add<T extends HiveObject>({
    required String boxName,
    required T value,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      await _lock.synchronized(() => box.add(value));
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
    }
  }

  /// `addAll`
  /// add multiple data to custom box
  Future<void> addAll<T extends HiveObject>({
    required String boxName,
    required List<T> values,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      await _lock.synchronized(() => box.addAll(values));
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
    }
  }

  /// `update`
  /// update item from data

  Future<void> update<T extends HiveObject>({
    required String boxName,
    required T value,
    bool Function(T)? filter,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      final data =
          box.values.firstWhereOrNull(filter ?? (element) => element == value);
      if (data != null) await _lock.synchronized(() => data.delete());
      await _lock.synchronized(() => box.add(value));
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
    }
  }

  /// `delete`
  /// delete item from data

  Future<void> delete<T extends HiveObject>({
    required String boxName,
    required T value,
    bool Function(T)? filter,
  }) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      final data =
          box.values.firstWhereOrNull(filter ?? (element) => element == value);
      await _lock.synchronized(() => data?.delete());
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
    }
  }

  /// private getter to access session
  Session? get _session => _sessionBox.values.firstOrNull;

  /// refreshToken
  /// getter to access accessToken
  String? get accessToken => _session?.accessToken;

  /// refreshToken
  /// getter to access refreshToken
  String? get refreshToken => _session?.refreshToken;

  /// createdAt
  /// getter to access createdAt
  DateTime? get createdAt => _session?.createdAt;

  /// updatedAt
  /// getter to access updatedAt
  DateTime? get updatedAt => _session?.updatedAt;

  /// `onSessionChange`
  /// returns stream of [bool] when data changes on box
  Stream<bool> get onSessionChange {
    return _sessionBox.watch().distinct().map<bool>((event) {
      return event.value != null;
    }).startWith(hasSession);
  }

  /// `hasSession`
  /// checks whether `Box<Session>` is not empty or [Session] is not null
  bool get hasSession {
    return _sessionBox.isNotEmpty && _session != null;
  }

  /// `saveToken`
  /// updates access token if exists or saves new one if not
  /// updates refresh token
  Future<void> saveToken(String token, [String? refreshToken]) async {
    _lock.synchronized(() async {
      if (hasSession) {
        _session!
          ..accessToken = token
          ..refreshToken = refreshToken
          ..updatedAt = DateTime.now();
        await _session!.save();
      } else {
        await _sessionBox.add(
          Session()
            ..accessToken = token
            ..refreshToken = refreshToken
            ..createdAt = DateTime.now(),
        );
      }
    });
  }

  /// `isTokenExpired`
  /// checks whether token is expired or not
  bool get isTokenExpired {
    if (!hasSession) return true;
    return JwtDecoder.isExpired(_session!.accessToken);
  }

  /// clearSession
  /// removes the [Session] value from [Box]
  Future<void> clearSession() async {
    await _lock.synchronized(() => _sessionBox.clear());
  }

  /// get
  /// get value from box associated with [key]
  T? get<T>({
    required String key,
    T? defaultValue,
  }) {
    return _cacheBox.get(key, defaultValue: defaultValue);
  }

  /// watch
  /// watch specific key for value changed

  Stream<T?> watchKey<T>({
    required String key,
  }) {
    return _cacheBox
        .watch(key: key)
        .distinct()
        .map<T?>((event) => event.value as T?);
  }

  /// getList
  /// get list data
  List<T> getList<T>({
    required String key,
    List<T> defaultValue = const [],
  }) {
    try {
      final String encodedData = _cacheBox.get(key, defaultValue: '');
      if (encodedData.isEmpty) return defaultValue;
      final decodedData = jsonDecode(_cacheBox.get(key));
      return List<T>.from(decodedData);
    } catch (_) {
      return defaultValue;
    }
  }

  /// save
  /// puts value in box with [key]
  Future<void> put<T>({
    required String key,
    required T value,
  }) async {
    return _cacheBox.put(key, value);
  }

  /// save list of data
  Future<void> putList<T>({
    required String key,
    required List<T> value,
  }) async {
    final encodedData = jsonEncode(value);
    return _cacheBox.put(key, encodedData);
  }

  /// save
  /// puts value in box with [key]
  Future<void> putAll({
    required Map<String, dynamic> entries,
  }) async {
    return _cacheBox.putAll(entries);
  }

  /// remove
  /// removes value from box registered with [key]
  Future<void> remove({
    required String key,
  }) async {
    return _lock.synchronized(() => _cacheBox.delete(key));
  }

  /// clear
  /// clear all values from box
  Future<int> clear() async {
    return _lock.synchronized(() => _cacheBox.clear());
  }

  /// clearAll
  /// clear all values from both session box and cache box
  /// doesnot clears box created using `openCustomBox()`
  Future<void> clearAll() async {
    return _lock.synchronized(() async {
      await _sessionBox.clear();
      await _cacheBox.clear();
    });
  }

  /// close all the opened box
  Future<void> closeAll() async {
    await _lock.synchronized(() {
      _sessionBox.close();
      _cacheBox.close();
    });
  }

  /// delete all the opened box
  Future<void> deleteAll() async {
    await _lock.synchronized(() {
      _sessionBox.deleteFromDisk();
      _cacheBox.deleteFromDisk();
      Hive.deleteFromDisk();
    });
  }

  /// convert box to map
  Map<String, Map<String, dynamic>?> toCacheMap() =>
      Map.unmodifiable(_cacheBox.toMap());
}
