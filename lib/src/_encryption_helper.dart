import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_local_storage/hive_local_storage.dart';

class EncryptionHelper {
  const EncryptionHelper._();

  static const _keyName = '__EncryptionKey__';

  static const _flutterSecureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// returns encryption cipher for boxes
  static Future<HiveCipher> hiveCipher(HiveCipher? customCipher) async {
    if (customCipher != null) return customCipher;
    return await _encryptionKey;
  }

  /// HiveAesCipher encryptionKey
  /// encryption key to secure session box
  static Future<HiveAesCipher> get _encryptionKey async {
    late Uint8List encryptionKey;
    var keyString = await _flutterSecureStorage.read(key: _keyName);
    if (keyString == null) {
      final key = Hive.generateSecureKey();
      await _flutterSecureStorage.write(
        key: _keyName,
        value: base64UrlEncode(key),
      );
      encryptionKey = Uint8List.fromList(key);
    } else {
      encryptionKey = base64Url.decode(keyString);
    }
    return HiveAesCipher(encryptionKey);
  }
}
