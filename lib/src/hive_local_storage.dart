import 'dart:async';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

import '_encryption_helper.dart';
import '_jwt_decoder.dart';
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

  /// [Box] session box
  static late Box<Session> _sessionBox;

  /// [Box] _cacheBox
  static late Box<dynamic> _cacheBox;

  /// path to store the boxes
  static String? _storagePath;

  /// encryption cipher for the boxes
  ///
  static late HiveCipher _encryptionCipher;

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
    String? storageDirectory,
    void Function()? registerAdapters,
    HiveCipher? customCipher,
  }) async {
    await _lock.synchronized(() async {
      final appDir = await getApplicationDocumentsDirectory();
      if (!kIsWeb) {
        _storagePath = appDir.path;
        _storagePath = p.join(_storagePath!, storageDirectory);
      }
      Hive.init(_storagePath);
      Hive.registerAdapter(SessionAdapter());
      registerAdapters?.call();
      _encryptionCipher = await EncryptionHelper.hiveCipher(customCipher);
      _sessionBox = await Hive.openBox<Session>(sessionKey, encryptionCipher: _encryptionCipher);
      _cacheBox = await Hive.openBox(cacheKey, encryptionCipher: _encryptionCipher);
    });
    return LocalStorage._();
  }

  /// `openBox`
  /// open custom box
  FutureOr<Box<T>> openBox<T>({
    required String boxName,
    @Deprecated('''use customCipher from getInstance() method instead
      will be removed in next version''') HiveCipher? customCipher,
    int? typeId,
  }) async {
    assert(typeId != 0, 'typeId 0 is already occupied by session');
    if (typeId != null && !Hive.isAdapterRegistered(typeId)) {
      throw Exception('Please register adapter for $T.');
    }
    return _lockGuard(() {
      customCipher ??= _encryptionCipher;
      return Hive.openBox<T>(
        boxName,
        encryptionCipher: customCipher,
      );
    });
  }

  /// `getBox`
  /// returns the previously opened box if exists
  /// otherwise opens the box and returns new box
  Future<Box<T>> getBox<T>(String name) async {
    return _lockGuard(
      () => Hive.box<T>(name),
      () => Hive.openBox<T>(name, encryptionCipher: _encryptionCipher),
    );
  }

  /// `put`
  /// puts data in cache box
  /// if [boxName] is provided then it will put data in custom box
  Future<void> put<T>({
    required String key,
    required T value,
    String? boxName,
  }) {
    return _lockGuard(() {
      if (boxName == null) return _cacheBox.put(key, value);
      return Hive.box<T>(boxName).put(key, value);
    });
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
    return _guard(() {
      if (boxName == null) return _cacheBox.get(key, defaultValue: defaultValue);
      return Hive.box(boxName).get(key, defaultValue: defaultValue);
    }, () {
      return defaultValue;
    });
  }

  /// `remove`
  /// removes data from cache box
  /// if [boxName] is provided then it will remove data from custom box
  Future<void> remove<T>({
    required String key,
    String? boxName,
  }) async {
    return _lockGuard(() {
      if (boxName == null) return _cacheBox.delete(key);
      return Hive.box<T>(boxName).delete(key);
    });
  }

  /// `values`
  /// get all the values from custom box
  List<T> values<T>(String boxName) {
    return _guard(() => Hive.box<T>(boxName).values.toList());
  }

  /// `add`
  /// add data to custom box
  Future<void> add<T>({
    required String boxName,
    required T value,
  }) async {
    return _lockGuard(() async {
      final box = Hive.box<T>(boxName);
      await box.add(value);
    });
  }

  /// `addAll`
  /// add multiple data to custom box
  Future<void> addAll<T>({
    required String boxName,
    required List<T> values,
  }) async {
    return _lockGuard(() async {
      final box = Hive.box<T>(boxName);
      await box.addAll(values);
    });
  }

  /// `update`
  /// update item from data
  ///
  /// only supports [HiveObject] type
  Future<void> update<T>({
    required String boxName,
    required T value,
    bool Function(T)? filter,
  }) {
    return _lockGuard(() async {
      final box = Hive.box<T>(boxName);
      final values = box.values.toList();
      values.removeWhere(filter ?? (element) => element == value);
      values.add(value);
      await box.clear();
      await box.addAll(values);
    });
  }

  /// `delete`
  /// delete item from data
  ///
  /// only supports [HiveObject] type
  Future<void> delete<T>({
    required String boxName,
    required T value,
    bool Function(T)? filter,
  }) {
    return _lockGuard(() async {
      final box = Hive.box<T>(boxName);
      final values = box.values.toList();
      values.removeWhere(filter ?? (element) => element == value);
      await box.clear();
      await box.addAll(values);
    });
  }

  /// private getter to access session
  Session? get _session => _guard(() => _sessionBox.values.firstOrNull);

  /// accessToken
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

  /// remainingTokenDuration
  /// returns remaining time of token
  Duration get remainingTokenDuration {
    return _guard(() {
      if (!hasSession) return Duration.zero;
      return JwtDecoder.getRemainingTime(_session!.accessToken);
    });
  }

  /// `onSessionChange`
  /// returns stream of [bool] when data changes on box
  Stream<bool> get onSessionChange {
    return _guard(
        () => _sessionBox.watch().distinct().map<bool>((event) {
              return event.value != null;
            }).startWith(hasSession),
        () => Stream.value(false));
  }

  /// `hasSession`
  /// checks whether `Box<Session>` is not empty or [Session] is not null
  bool get hasSession {
    return _guard(() => _sessionBox.isNotEmpty && _session != null, () => false);
  }

  /// `saveToken`
  /// updates access token if exists or saves new one if not
  /// updates refresh token
  Future<void> saveToken(String token, [String? refreshToken]) {
    return _lockGuard(() async {
      if (hasSession) {
        _session!
          ..accessToken = token
          ..refreshToken = refreshToken
          ..updatedAt = DateTime.now();
        return _session!.save();
      } else {
        final session = Session()
          ..accessToken = token
          ..refreshToken = refreshToken
          ..createdAt = DateTime.now();
        await _sessionBox.clear();
        await _sessionBox.add(session);
      }
    });
  }

  /// `isTokenExpired`
  /// checks whether token is expired or not
  bool? get isTokenExpired {
    return _guard(() {
      if (!hasSession) return null;
      return JwtDecoder.isExpired(_session!.accessToken);
    });
  }

  /// clearSession
  /// removes the [Session] value from [Box]
  Future<void> clearSession() {
    return _lockGuard(_sessionBox.clear);
  }

  /// watch
  /// watch specific key for value changed
  Stream<T?> watchKey<T>({
    required String key,
    String? boxName,
  }) {
    return _guard(() {
      if (boxName == null) return _cacheBox.watch(key: key).distinct().map<T?>((event) => event.value as T?);
      final box = Hive.box<T>(boxName);
      return box.watch(key: key).distinct().map<T?>((event) => event.value as T?);
    });
  }

  /// getList
  /// get list data
  List<T> getList<T>({
    required String key,
    List<T> defaultValue = const [],
  }) {
    return _guard(
      () {
        final encodedData = _cacheBox.get(key, defaultValue: '');
        if (encodedData.isEmpty) return defaultValue;
        final decodedData = jsonDecode(encodedData);
        return List<T>.of(decodedData);
      },
      () => defaultValue,
    );
  }

  /// save list of data
  Future<void> putList<T>({
    required String key,
    required List<T> value,
  }) async {
    return _lockGuard(() {
      final encodedData = jsonEncode(value);
      return _cacheBox.put(key, encodedData);
    });
  }

  /// save
  /// puts value in box with [key]
  Future<void> putAll({
    required Map<String, dynamic> entries,
  }) async {
    return _lockGuard(() => _cacheBox.putAll(entries));
  }

  /// clear
  /// clear all values from box
  Future<int> clear() async {
    return _lockGuard(_cacheBox.clear);
  }

  /// `writeAndClose`
  /// write value to box and close the box
  static Future<void> writeAndClose<T>({
    required String boxName,
    required String key,
    required T value,
  }) async {
    return _lock.synchronized(() async {
      try {
        /// open new box
        final box = await Hive.openBox<T>(
          boxName,
          encryptionCipher: _encryptionCipher,
        );

        /// put value
        await box.put(key, value);

        /// close the box
        await box.close();
      } catch (e, s) {
        throw Error.throwWithStackTrace(e, s);
      }
    });
  }

  /// `readAndClose`
  /// read value from box and close the box
  static Future<T?> readAndClose<T>({
    required String key,
    required String boxName,
  }) async {
    return _lock.synchronized(() async {
      try {
        /// open new box
        final box = await Hive.openBox<T>(boxName, encryptionCipher: _encryptionCipher);

        /// get value
        final value = box.get(key);

        /// close the box
        await box.close();

        /// return value
        return value;
      } catch (e, s) {
        throw Error.throwWithStackTrace(e, s);
      }
    });
  }

  /// clearAll
  /// clear all values from both session box and cache box
  /// does not clears box created using `openBox()`
  Future<void> clearAll() async {
    return _lockGuard(() {
      Future.wait([
        _sessionBox.clear(),
        _cacheBox.clear(),
      ]);
    });
  }

  /// close all the opened box
  Future<void> closeAll() async {
    return _lockGuard(() {
      Future.wait([
        _sessionBox.close(),
        _cacheBox.close(),
        Hive.close(),
      ]);
    });
  }

  /// delete all the opened box
  Future<void> deleteAll() {
    return _lockGuard(() {
      Future.wait([
        _sessionBox.deleteFromDisk(),
        _cacheBox.deleteFromDisk(),
        Hive.deleteFromDisk(),
      ]);
    });
  }

  /// convert box to map
  Map<String, Map<String, dynamic>?> toCacheMap() => Map.unmodifiable(_cacheBox.toMap());

  /// common guard for all the methods
  Future<T> _lockGuard<T>(
    FutureOr<T> Function() action, [
    FutureOr<T> Function()? onError,
  ]) {
    return _lock.synchronized(() async {
      try {
        return await action();
      } catch (e, s) {
        if (onError != null) {
          return await onError();
        } else {
          throw Error.throwWithStackTrace(e, s);
        }
      }
    });
  }

  /// guard for non async methods
  T _guard<T>(T Function() action, [T Function()? onError]) {
    try {
      return action();
    } catch (e, s) {
      if (onError != null) {
        return onError();
      } else {
        throw Error.throwWithStackTrace(e, s);
      }
    }
  }
}
