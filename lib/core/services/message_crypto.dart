import 'package:encrypt/encrypt.dart' as encrypt;

class MessageCrypto {
  MessageCrypto._();

  static final encrypt.Key _key = encrypt.Key.fromUtf8(
    '0123456789abcdef0123456789abcdef',
  );
  static final encrypt.Encrypter _encrypter =
      encrypt.Encrypter(encrypt.AES(_key));

  static String encryptString(String plainText) {
    if (plainText.isEmpty) {
      return '';
    }

    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decryptString(String cipherText) {
    if (cipherText.isEmpty) {
      return '';
    }

    final parts = cipherText.split(':');
    if (parts.length != 2) {
      return cipherText;
    }

    try {
      return _encrypter.decrypt(
        encrypt.Encrypted.fromBase64(parts[1]),
        iv: encrypt.IV.fromBase64(parts[0]),
      );
    } catch (_) {
      return cipherText;
    }
  }
}