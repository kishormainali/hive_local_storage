import 'dart:math';
import 'dart:typed_data';

import 'package:hive_local_storage/hive_local_storage.dart';
import 'package:hive_local_storage/src/_crypto/_crc32.dart';
import 'package:pointycastle/export.dart';

class AesGcmCipher implements HiveCipher {
  AesGcmCipher(this.key)
    : assert(
        key.length == 32 && key.every((it) => it >= 0 && it <= 255),
        'The encryption key has to be a 32 byte (256 bit) array.',
      ) {
    final keyBytes = Uint8List.fromList(key);
    final sha256 = Digest('SHA-256');
    _keyCrc = Crc32.compute(sha256.process(keyBytes));
  }

  final Uint8List key;

  late final int _keyCrc;

  Uint8List _generateIV(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
  }

  @override
  int calculateKeyCrc() => _keyCrc;
  @override
  int decrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    if (inpLength < 12 + 16) {
      throw ArgumentError('Input too short to contain IV + tag + cipherText.');
    }

    final iv = inp.sublist(inpOff, inpOff + 12);
    final cipherText = inp.sublist(inpOff + 12, inpOff + inpLength);

    final gcm = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final decrypted = gcm.process(cipherText);
    out.setRange(outOff, outOff + decrypted.length, decrypted);

    return decrypted.length;
  }

  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final iv = _generateIV(12);
    final gcm = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final plaintext = inp.sublist(inpOff, inpOff + inpLength);
    final encrypted = gcm.process(plaintext);

    // Store: IV (12) | cipherText + tag (encrypted)
    out.setRange(outOff, outOff + iv.length, iv);
    out.setRange(
      outOff + iv.length,
      outOff + iv.length + encrypted.length,
      encrypted,
    );

    return iv.length + encrypted.length;
  }

  @override
  int maxEncryptedSize(Uint8List inp) {
    return inp.length + 16; // 16 bytes for GCM nonce
  }
}
