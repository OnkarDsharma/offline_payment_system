import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalKeyPair {
  const LocalKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  final String publicKey;
  final String privateKey;
}

class KeyManager {
  KeyManager({
    FlutterSecureStorage? storage,
    Ed25519? algorithm,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _algorithm = algorithm ?? Ed25519();

  static const publicKeyField = 'offline_public_key';
  static const privateKeyField = 'offline_private_key';

  final FlutterSecureStorage _storage;
  final Ed25519 _algorithm;

  Future<LocalKeyPair> ensureKeyPair() async {
    final existingPublic = await _storage.read(key: publicKeyField);
    final existingPrivate = await _storage.read(key: privateKeyField);

    if (existingPublic != null && existingPrivate != null) {
      return LocalKeyPair(
          publicKey: existingPublic, privateKey: existingPrivate);
    }

    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final encodedPublic = base64UrlEncode(publicKey.bytes);
    final encodedPrivate = base64UrlEncode(privateKeyBytes);

    await _storage.write(key: publicKeyField, value: encodedPublic);
    await _storage.write(key: privateKeyField, value: encodedPrivate);

    return LocalKeyPair(
      publicKey: encodedPublic,
      privateKey: encodedPrivate,
    );
  }

  Future<String?> getPublicKey() => _storage.read(key: publicKeyField);

  Future<String?> getPrivateKey() => _storage.read(key: privateKeyField);
}
