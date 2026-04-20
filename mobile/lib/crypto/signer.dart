import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class Signer {
  String sign(String payload, String privateKey) {
    final digest = HMac(SHA256Digest(), 64);
    digest.init(KeyParameter(Uint8List.fromList(utf8.encode(privateKey))));
    final bytes = digest.process(Uint8List.fromList(utf8.encode(payload)));
    return base64Encode(bytes);
  }

  bool verify({
    required String payload,
    required String signature,
    required String privateKey,
  }) {
    return sign(payload, privateKey) == signature;
  }
}