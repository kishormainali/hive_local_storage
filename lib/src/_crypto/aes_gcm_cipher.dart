import 'dart:math';
import 'dart:typed_data';

import 'package:hive_local_storage/hive_local_storage.dart';
import 'package:hive_local_storage/src/_crypto/_crc32.dart';
import 'package:pointycastle/export.dart';

/// An implementation of [HiveCipher] using AES-256 in GCM (Galois/Counter Mode) mode.
///
/// This cipher provides authenticated encryption with associated data (AEAD), which
/// ensures both confidentiality and authenticity of the encrypted data. GCM mode
/// includes built-in authentication tags to detect tampering.
///
/// Key features:
/// - Uses AES-256 encryption (256-bit key)
/// - GCM mode for authenticated encryption
/// - Random 12-byte IV (initialization vector) for each encryption
/// - 128-bit authentication tag
///
/// The encrypted output format is: `IV (12 bytes) | CipherText + Tag`
class AesGcmCipher implements HiveCipher {
  /// Creates an AES-GCM cipher with the provided encryption key.
  ///
  /// The [key] must be exactly 32 bytes (256 bits) long and contain values
  /// in the range 0-255. The key is hashed using SHA-256 and a CRC32 checksum
  /// is computed for key verification.
  ///
  /// Throws an [AssertionError] if the key doesn't meet the requirements.
  AesGcmCipher(this.key)
    : assert(
        key.length == 32 && key.every((it) => it >= 0 && it <= 255),
        'The encryption key has to be a 32 byte (256 bit) array.',
      ) {
    final keyBytes = Uint8List.fromList(key);
    final sha256 = Digest('SHA-256');
    _keyCrc = Crc32.compute(sha256.process(keyBytes));
  }

  /// The 32-byte encryption key used for AES-256 encryption.
  final Uint8List key;

  /// CRC32 checksum of the SHA-256 hash of the encryption key.
  ///
  /// This is used to verify the key integrity without exposing the actual key.
  late final int _keyCrc;

  /// Shared secure RNG. [Random.secure] pulls from the platform's CSPRNG on
  /// construction, so a single cached instance is reused for every IV
  /// instead of paying that setup cost on every encrypt call.
  static final Random _secureRandom = Random.secure();

  /// Reused GCM/AES engine instances (one per direction) to avoid allocating
  /// a fresh [AESEngine]/[GCMBlockCipher] on every encrypt/decrypt call.
  /// Each call still re-initializes them with a fresh IV, as required by GCM.
  late final GCMBlockCipher _encryptCipher = GCMBlockCipher(AESEngine());
  late final GCMBlockCipher _decryptCipher = GCMBlockCipher(AESEngine());

  /// Generates a cryptographically secure random initialization vector (IV).
  ///
  /// Uses the cached [_secureRandom] to generate random bytes for the IV.
  ///
  /// Parameters:
  /// - [length]: The length of the IV in bytes (typically 12 for GCM mode)
  ///
  /// Returns a [Uint8List] containing the random IV.
  Uint8List _generateIV(int length) {
    final iv = Uint8List(length);
    for (var i = 0; i < length; i++) {
      iv[i] = _secureRandom.nextInt(256);
    }
    return iv;
  }

  /// Calculates and returns the CRC32 checksum of the encryption key.
  ///
  /// This checksum is used by Hive to verify that the correct encryption key
  /// is being used to decrypt data.
  @override
  int calculateKeyCrc() => _keyCrc;

  /// Decrypts the input data using AES-256-GCM.
  ///
  /// The input data must be in the format: `IV (12 bytes) | CipherText + Tag`
  ///
  /// Parameters:
  /// - [inp]: The input byte array containing encrypted data
  /// - [inpOff]: The offset in the input array where the encrypted data starts
  /// - [inpLength]: The length of the encrypted data (must be at least 28 bytes: 12 for IV + 16 for tag)
  /// - [out]: The output byte array where decrypted data will be written
  /// - [outOff]: The offset in the output array where decrypted data should start
  ///
  /// Returns the number of bytes written to the output array.
  ///
  /// Throws an [ArgumentError] if the input is too short to contain IV and authentication tag.
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

    _decryptCipher.init(
      false,
      AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
    );

    final decrypted = _decryptCipher.process(cipherText);
    out.setRange(outOff, outOff + decrypted.length, decrypted);

    return decrypted.length;
  }

  /// Encrypts the input data using AES-256-GCM.
  ///
  /// A random 12-byte IV is generated for each encryption operation.
  /// The output format is: `IV (12 bytes) | CipherText + Tag`
  ///
  /// Parameters:
  /// - [inp]: The input byte array containing plaintext data
  /// - [inpOff]: The offset in the input array where the plaintext starts
  /// - [inpLength]: The length of the plaintext data
  /// - [out]: The output byte array where encrypted data will be written
  /// - [outOff]: The offset in the output array where encrypted data should start
  ///
  /// Returns the total number of bytes written to the output array
  /// (IV length + encrypted data length + tag length).
  @override
  int encrypt(
    Uint8List inp,
    int inpOff,
    int inpLength,
    Uint8List out,
    int outOff,
  ) {
    final iv = _generateIV(12);
    _encryptCipher.init(
      true,
      AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
    );

    final plaintext = inp.sublist(inpOff, inpOff + inpLength);
    final encrypted = _encryptCipher.process(plaintext);

    // Store: IV (12) | cipherText + tag (encrypted)
    out.setRange(outOff, outOff + iv.length, iv);
    out.setRange(
      outOff + iv.length,
      outOff + iv.length + encrypted.length,
      encrypted,
    );

    return iv.length + encrypted.length;
  }

  /// Calculates the maximum size of the encrypted output for a given input.
  ///
  /// The encrypted size includes:
  /// - Original data length
  /// - 12 bytes for the IV
  /// - 16 bytes for the GCM authentication tag
  ///
  /// Note: The comment in the original code mentions "GCM nonce" but this
  /// actually refers to the 12-byte IV plus the 16-byte authentication tag.
  /// The return value adds 16 to account for overhead, as the IV (12 bytes)
  /// is already included in the encryption process.
  ///
  /// Parameters:
  /// - [inp]: The input data to be encrypted
  ///
  /// Returns the maximum number of bytes needed to store the encrypted data.
  @override
  int maxEncryptedSize(Uint8List inp) {
    return inp.length + 16; // 16 bytes for GCM nonce
  }
}
