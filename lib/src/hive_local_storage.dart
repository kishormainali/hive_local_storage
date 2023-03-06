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
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    await _lock.synchronized(() async {
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
      );
      final encryptionCipher = await _encryptionKey;
      await Hive.initFlutter();
      Hive.registerAdapter(SessionAdapter());
      registerAdapters?.call();
      _sessionBox = await Hive.openBox<Session>(sessionKey);
      _cacheBox =
          await Hive.openBox(cacheKey, encryptionCipher: encryptionCipher);
    });
    return LocalStorage._();
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
  Future<void> openCustomBox<T extends HiveObject>({
    required String boxName,
    required int typeId,
  }) async {
    if (!Hive.isAdapterRegistered(typeId)) {
      throw Exception('Please register adapter for $T before opening box.');
    }
    await _lock.synchronized(
      () async => Hive.openBox<T>(
        boxName,
        encryptionCipher: await _encryptionKey,
      ),
    );
  }

  /// `getCustomList`
  /// get data from custom box
  List<T> getCustomList<T extends HiveObject>({
    required String boxName,
  }) {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      return box.values.toList();
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
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
  Future<void> update<T extends HiveObject>(
      {required String boxName, required T value}) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      final data = box.values.firstWhereOrNull((element) => element == value);
      if (data != null) await _lock.synchronized(() => data.delete());
      await _lock.synchronized(() => box.add(value));
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
    }
  }

  /// `delete`
  /// delete item from data
  Future<void> delete<T extends HiveObject>(
      {required String boxName, required T value}) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<T>(boxName);
      final data = box.values.firstWhereOrNull((element) => element == value);
      await _lock.synchronized(() => data?.delete());
    } else {
      throw Exception('Please `openCustomBox` before accessing it');
    }
  }

  /// `getSession`
  /// get [Session] from the box
  Session? getSession() {
    return _sessionBox.values.firstOrNull;
  }

  /// `onSessionChange`
  /// returns stream of [Session] when data changes on box
  Stream<Session?> get onSessionChange {
    return _sessionBox.watch().distinct().map<Session?>((event) {
      return event.value;
    }).startWith(getSession());
  }

  /// `hasSession`
  /// checks whether `Box<Session>` is not empty or [Session] is not null
  bool get hasSession {
    return _sessionBox.isNotEmpty && getSession() != null;
  }

  /// `saveSession`
  /// clears the previously stored value and adds new [Session]
  Future<void> saveSession(Session session) async {
    await _lock.synchronized(() {
      if (_sessionBox.isEmpty) {
        _sessionBox.add(session);
      } else {
        _sessionBox.putAt(0, session);
      }
    });
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

  /// getList
  /// get list data
  List<T> getList<T>({required String key, List<T> defaultValue = const []}) {
    try {
      final String encodedData = _cacheBox.get(key, defaultValue: '');
      if (encodedData.isEmpty) return defaultValue;
      final decodedData = jsonDecode(_cacheBox.get(key));
      return List<T>.from(jsonDecode(decodedData));
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
  Future<void> remove({required String key}) async {
    return _lock.synchronized(() => _cacheBox.delete(key));
  }

  /// clear
  /// clear all values from box
  Future<int> clear() async {
    return _lock.synchronized(() => _cacheBox.clear());
  }

  /// close all the opened box
  Future<void> closeAll() async {
    await _lock.synchronized(() {
      _sessionBox.close();
      _cacheBox.close();
    });
  }

  /// convert box to map
  Map<String, Map<String, dynamic>?> toCacheMap() =>
      Map.unmodifiable(_cacheBox.toMap());
}
