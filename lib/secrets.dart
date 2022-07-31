import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/api.dart';

const _headerSize = 24;

BlockCipher _initializeCipher(bool encrypt, Uint8List header, String password) {
  final passwordBytes = Uint8List.fromList(utf8.encode(password));
  final saltView = Uint8List.view(header.buffer, 0, 8);
  final ivView = Uint8List.view(header.buffer, 8, 16);

  final derivator = KeyDerivator('SHA-1/HMAC/PBKDF2');
  derivator.init(Pbkdf2Parameters(saltView, 2000, 32));
  final keyBytes = derivator.process(passwordBytes);

  final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
    ..init(
      encrypt,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(keyBytes), ivView),
        null,
      ),
    );

  return cipher;
}

String _encrypt(String password, String plaintext) {
  final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

  final header = Uint8List(_headerSize);
  final rand = Random.secure();
  for (var i = 0; i < 16; i++) {
    header[i] = rand.nextInt(256);
  }

  final cipher = _initializeCipher(true, header, password);

  final ciphertext = cipher.process(plaintextBytes);

  return base64.encode([
    ...header,
    ...ciphertext,
  ]);
}

String _decrypt(String password, String ciphertext) {
  final ciphertextBytes = Uint8List.fromList(base64.decode(ciphertext));

  final headerView = Uint8List.view(ciphertextBytes.buffer, 0, _headerSize);

  final ciphertextView = Uint8List.view(
    ciphertextBytes.buffer,
    _headerSize,
    ciphertextBytes.length - _headerSize,
  );

  final cipher = _initializeCipher(false, headerView, password);

  final plaintextBytes = cipher.process(ciphertextView);

  return utf8.decode(plaintextBytes);
}

String decryptSecret(String name, String value) {
  final key = Platform.environment['BEEPER_SECRET_KEY'];
  if (key == null) return value;
  return _decrypt('$name/$key', value);
}

String encryptSecret(String name, String value) {
  final key = Platform.environment['BEEPER_SECRET_KEY'];
  assert(key != null, 'BEEPER_SECRET_KEY not provided');
  return _encrypt('$name/$key', value);
}
