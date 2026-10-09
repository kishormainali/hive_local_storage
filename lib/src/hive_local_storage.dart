import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:hive_local_storage/src/_crypto/aes_gcm_cipher.dart';
import 'package:pointycastle/export.dart';
import 'package:synchronized/synchronized.dart';

import '_secure_storage.dart';

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

  /// lock guarding structural changes (opening/closing/clearing boxes,
  /// migrations) that touch shared state such as [_openedBoxes]/[_cacheBox].
  static final _lock = Lock();

  /// per-box locks so writes to independent boxes don't serialize behind
  /// each other; only concurrent access to the *same* box is synchronized.
  static final Map<String, Lock> _boxLocks = {};

  /// returns (creating if needed) the lock for [boxName]
  static Lock _lockFor(String boxName) =>
      _boxLocks.putIfAbsent(boxName, Lock.new);

  /// cache key
  static const String cacheKey = '__CACHE_KEY__';

  /// new cache box key
  static const String newCacheBoxKey = '__NEW_CACHE_KEY__';

  /// encryption key
  static const String encryptionBoxKey = '__ENCRYPTION_KEY__';

  /// new encryption key
  static const String newEncryptionBoxKey = '__NEW_ENCRYPTION_KEY__';

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
      // initialize hive
      await Hive.initFlutter(storageDirectory);
      // register adapters
      registerAdapters?.call();

      /// migrate to new encryption if needed
      await _migrateToNewEncryptionIfNeeded(customCipher);
    });

    _instance ??= LocalStorage._();
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
      var keyString = await SecureStorage.i.get(newEncryptionBoxKey);
      encryptionKey = keyString == null
          ? await __newEncryptionCipher
          : base64.decode(keyString);
      return AesGcmCipher(encryptionKey);
    } on PlatformException catch (_) {
      await SecureStorage.i.delete(newEncryptionBoxKey);
      return AesGcmCipher(await __newEncryptionCipher);
    }
  }

  /// Generate new encryption key
  static Future<Uint8List> get __newEncryptionCipher async {
    final newKey = Hive.generateSecureKey();
    await SecureStorage.i.set(newEncryptionBoxKey, base64.encode(newKey));
    return Uint8List.fromList(newKey);
  }

  /// `openBox`
  /// open custom box
  FutureOr<Box<T>> openBox<T>({
    required String boxName,
    HiveCipher? customCipher,
    int? typeId,
  }) async {
    // already open: return immediately, skip locking and cipher lookup
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    if (typeId != null && !Hive.isAdapterRegistered(typeId)) {
      throw Exception('Please register adapter for $T.');
    }
    return await _lock.synchronized(() async {
      // re-check: another caller may have opened it while we awaited the lock
      if (Hive.isBoxOpen(boxName)) return Hive.box<T>(boxName);
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
    // `isBoxOpen` already implies the box exists; no need for an extra
    // async disk existence check.
    if (Hive.isBoxOpen(name)) {
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
        await _lockFor(boxName).synchronized(() {
          final box = Hive.box<T>(boxName);
          return box.put(key, value);
        });
      } else {
        throw Exception('Please `openBox` before accessing it');
      }
    } else {
      await _lockFor(
        newCacheBoxKey,
      ).synchronized(() => _cacheBox.put(key, value));
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
      try {
        return _cacheBox.get(key, defaultValue: defaultValue);
      } on InvalidCipherTextException catch (_) {
        _cacheBox.delete(key).ignore();
        return defaultValue;
      }
    }
  }

  /// `remove`
  /// removes data from cache box
  /// if [boxName] is provided then it will remove data from custom box
  Future<void> remove<T>({required String key, String? boxName}) async {
    if (boxName != null) {
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<T>(boxName);
        await _lockFor(boxName).synchronized(() => box.delete(key));
      } else {
        throw Exception('Please `openBox` before accessing it');
      }
    } else {
      await _lockFor(newCacheBoxKey).synchronized(() => _cacheBox.delete(key));
    }
  }

  /// `values`
  /// get all the values from custom box
  List<T> values<T>(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      try {
        final box = Hive.box<T>(boxName);
        return box.values.toList();
      } on InvalidCipherTextException catch (_) {
        Hive.box(boxName).clear().ignore();
        return [];
      }
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
  }

  /// `add`
  /// add data to custom box
  Future<void> add<T>({required String boxName, required T value}) async {
    if (Hive.isBoxOpen(boxName)) {
      await _lockFor(boxName).synchronized(() {
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
      await _lockFor(boxName).synchronized(() {
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
      await _lockFor(boxName).synchronized(() async {
        final data = box.values.firstWhereOrNull(
          filter ?? (element) => element == value,
        );
        if (data != null) await data.delete();
        await box.add(value);
      });
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
      await _lockFor(boxName).synchronized(() {
        final data = box.values.firstWhereOrNull(
          filter ?? (element) => element == value,
        );
        return data?.delete();
      });
    } else {
      throw Exception('Please `openBox` before accessing it');
    }
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
      final decodedData = jsonDecode(encodedData);
      return List<T>.of(decodedData);
    } catch (_) {
      _cacheBox.delete(key).ignore();
      return defaultValue;
    }
  }

  /// save list of data
  Future<void> putList<T>({required String key, required List<T> value}) async {
    final encodedData = jsonEncode(value);
    return _lockFor(
      newCacheBoxKey,
    ).synchronized(() => _cacheBox.put(key, encodedData));
  }

  /// save
  /// puts value in box with [key]
  Future<void> putAll({required Map<String, dynamic> entries}) async {
    return _lockFor(
      newCacheBoxKey,
    ).synchronized(() => _cacheBox.putAll(entries));
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
    return _lockFor(boxName).synchronized(() async {
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
    return _lockFor(boxName).synchronized(() async {
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
      await Future.wait([_cacheBox.clear(), ...futures]);
    });
  }

  /// close all the opened boxes
  Future<void> closeAll() async {
    await _lock.synchronized(() {
      _openedBoxes.clear();
      return Future.wait([_cacheBox.close(), Hive.close()]);
    });
  }

  /// delete all the opened box
  Future<void> deleteAll() async {
    await _lock.synchronized(() {
      _openedBoxes.clear();
      return Future.wait([
        _cacheBox.deleteFromDisk(),
        Hive.deleteFromDisk(),
        SecureStorage.i.delete(newEncryptionBoxKey),
      ]);
    });
  }

  /// convert box to map
  Map<String, Map<String, dynamic>?> toCacheMap() => Map.unmodifiable({
    "cache": _cacheBox.toMap(),
    for (var boxName in _openedBoxes)
      if (Hive.isBoxOpen(boxName)) boxName: Hive.box(boxName).toMap(),
  });

  /// migrate to new encryption if needed
  static Future<void> _migrateToNewEncryptionIfNeeded(
    HiveCipher? customCipher,
  ) async {
    try {
      // check if old box exists
      final isOldBoxExists = await Hive.boxExists(cacheKey);
      if (!isOldBoxExists) {
        await openNewCacheBox(customCipher);
        return;
      }

      // get old encryption key
      final oldEncryptionKey = await SecureStorage.i.get(encryptionBoxKey);
      if (oldEncryptionKey == null) {
        await openNewCacheBox(customCipher);
        return;
      }

      // open old box with old encryption key and migrate data
      final oldCipher = HiveAesCipher(base64.decode(oldEncryptionKey));
      final oldBox = await Hive.openBox<dynamic>(
        cacheKey,
        encryptionCipher: oldCipher,
      );
      final data = oldBox.toMap();
      await oldBox.clear();
      await oldBox.deleteFromDisk();

      await SecureStorage.i.delete(encryptionBoxKey);
      await openNewCacheBox(customCipher);
      await _cacheBox.putAll(data);
    } catch (_) {
      await Hive.deleteFromDisk();
      await SecureStorage.i.delete(encryptionBoxKey);
      await openNewCacheBox(customCipher);
    }
  }

  // open new cache box
  // if the box is unreadable (wrong cipher / corrupted), wipe it and the key
  // and start fresh instead of crashing on initialize
  static Future<void> openNewCacheBox(HiveCipher? customCipher) async {
    try {
      _cacheBox = await Hive.openBox<dynamic>(
        newCacheBoxKey,
        encryptionCipher: await _cipher(customCipher),
      );
    } catch (_) {
      await Hive.deleteBoxFromDisk(newCacheBoxKey);
      if (customCipher == null) {
        await SecureStorage.i.delete(newEncryptionBoxKey);
      }
      _cacheBox = await Hive.openBox<dynamic>(
        newCacheBoxKey,
        encryptionCipher: await _cipher(customCipher),
      );
    }
  }
}
