import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_local_storage/hive_local_storage.dart';
import 'package:hive_local_storage/src/secure_storage.dart';

///{@template encryption_helper}
/// Helper class to manage encryption keys for Hive boxes.
/// This class provides methods to generate, retrieve, and manage encryption keys.
/// It uses secure storage to persist the encryption keys.
/// It also provides a method to create a new cipher.
/// {@endtemplate}
class EncryptionHelper {
  /// {@macro encryption_helper}
  /// This class is a singleton and should not be instantiated directly.
  const EncryptionHelper._();

  /// Encryption key name
  static const _keyName = '__EncryptionKey__';

  /// SecureStorage instance
  static final _secureStorage = SecureStorage();

  /// returns encryption cipher for boxes
  static Future<HiveCipher> hiveCipher(HiveCipher? customCipher) async {
    if (customCipher != null) return customCipher;
    return _encryptionKey;
  }

  /// creates new cipher
  static Future<HiveCipher> newCipher([List<int>? key]) async {
    key ??= Hive.generateSecureKey();
    return HiveAesCipher(Uint8List.fromList(key));
  }

  /// HiveAesCipher encryptionKey
  /// encryption key to secure session box
  static Future<HiveAesCipher> get _encryptionKey async {
    try {
      late Uint8List encryptionKey;
      var keyString = await _secureStorage.get(_keyName);
      if (keyString == null) {
        final key = Hive.generateSecureKey();
        await _secureStorage.save(key: _keyName, value: base64UrlEncode(key));
        encryptionKey = Uint8List.fromList(key);
      } else {
        encryptionKey = base64Url.decode(keyString);
      }
      return HiveAesCipher(encryptionKey);
    } catch (_) {
      await _secureStorage.delete(_keyName);
      final bytes = Uint8List.fromList(Hive.generateSecureKey());
      await _secureStorage.save(key: _keyName, value: base64UrlEncode(bytes));
      return HiveAesCipher(bytes);
    }
  }
}
