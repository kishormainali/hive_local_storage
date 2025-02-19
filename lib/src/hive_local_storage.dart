import 'dart:async';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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
    String? storageDirectory,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    await _lock.synchronized(() async {
      await Hive.initFlutter(storageDirectory);
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
    try {
      late Uint8List encryptionKey;
      var keyString = await _storage.read(key: encryptionBoxKey);
      encryptionKey = keyString == null
          ? await _newEncryptionkey
          : base64Url.decode(keyString);
      return HiveAesCipher(encryptionKey);
    } on PlatformException catch (_) {
      await _storage.deleteAll();
      return HiveAesCipher(await _newEncryptionkey);
    }
  }

  /// Generate new encryption key
  static Future<Uint8List> get _newEncryptionkey async {
    final newKey = Hive.generateSecureKey();
    await _storage.write(key: encryptionBoxKey, value: base64UrlEncode(newKey));
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
    return await _lock.synchronized(
      () async => Hive.openBox<T>(
        boxName,
        encryptionCipher: await _cipher(customCipher),
      ),
    );
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
  T? get<T>({
    required String key,
    T? defaultValue,
    String? boxName,
  }) {
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
  Future<void> remove<T>({
    required String key,
    String? boxName,
  }) async {
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
  Future<void> add<T>({
    required String boxName,
    required T value,
  }) async {
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
      final data =
          box.values.firstWhereOrNull(filter ?? (element) => element == value);
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
      final data =
          box.values.firstWhereOrNull(filter ?? (element) => element == value);
      await _lock.synchronized(() => data?.delete());
    } else {
      throw Exception('Please `openBox` before accessing it');
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
  bool? get isTokenExpired {
    if (!hasSession) return null;
    return JwtDecoder.isExpired(_session!.accessToken);
  }

  /// clearSession
  /// removes the [Session] value from [Box]
  Future<void> clearSession() async {
    await _lock.synchronized(() => _sessionBox.clear());
  }

  /// watch
  /// watch specific key for value changed
  Stream<T?> watchKey<T>({
    required String key,
    String? boxName,
  }) {
    if (boxName != null) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<T>(boxName);
        return box
            .watch(key: key)
            .distinct()
            .map<T?>((event) => event.value as T?);
      } else {
        throw Exception(
            '$boxName is not yet opened, Please `openBox` before accessing it');
      }
    } else {
      return _cacheBox
          .watch(key: key)
          .distinct()
          .map<T?>((event) => event.value as T?);
    }
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
      return List<T>.of(decodedData);
    } catch (_) {
      return defaultValue;
    }
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

  /// clear
  /// clear all values from box
  Future<int> clear() async {
    return _lock.synchronized(() => _cacheBox.clear());
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
      final box =
          await Hive.openBox<T>(boxName, encryptionCipher: await _cipher(null));

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
      final box =
          await Hive.openBox<T>(boxName, encryptionCipher: await _cipher(null));
      final value = box.get(key);

      /// close the box
      await box.close();

      /// return value
      return value;
    });
  }

  /// clearAll
  /// clear all values from both session box and cache box
  /// does not clears box created using `openCustomBox()`
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
      Hive.close();
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
