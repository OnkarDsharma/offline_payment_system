import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

class LocalKeyPair {
  const LocalKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  final String publicKey;
  final String privateKey;
}

class KeyManager {
  KeyManager() : _storage = const FlutterSecureStorage();

  static const _publicKeyField = 'offline_wallet_public_key';
  static const _privateKeyField = 'offline_wallet_private_key';

  final FlutterSecureStorage _storage;

  Future<LocalKeyPair> ensureKeyPair() async {
    final existingPublic = await _storage.read(key: _publicKeyField);
    final existingPrivate = await _storage.read(key: _privateKeyField);

    if (existingPublic != null && existingPrivate != null) {
      return LocalKeyPair(publicKey: existingPublic, privateKey: existingPrivate);
    }

    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    final secureRandom = FortunaRandom()..seed(KeyParameter(seed));
    final privateKey = base64UrlEncode(secureRandom.nextBytes(32));
    final publicKey = base64UrlEncode(secureRandom.nextBytes(32));

    await _storage.write(key: _publicKeyField, value: publicKey);
    await _storage.write(key: _privateKeyField, value: privateKey);

    return LocalKeyPair(publicKey: publicKey, privateKey: privateKey);
  }

  Future<String?> getPublicKey() {
    return _storage.read(key: _publicKeyField);
  }

  Future<String?> getPrivateKey() {
    return _storage.read(key: _privateKeyField);
  }
}