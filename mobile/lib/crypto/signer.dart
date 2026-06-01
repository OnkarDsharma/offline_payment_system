import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class Signer {
  Signer({Ed25519? algorithm}) : _algorithm = algorithm ?? Ed25519();

  final Ed25519 _algorithm;

  Future<String> sign({
    required String payload,
    required String privateKey,
    required String publicKey,
  }) async {
    final keyPair = SimpleKeyPairData(
      convert.base64Url.decode(privateKey),
      publicKey: SimplePublicKey(
        convert.base64Url.decode(publicKey),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );

    final signature = await _algorithm.sign(
      Uint8List.fromList(convert.utf8.encode(payload)),
      keyPair: keyPair,
    );

    return convert.base64UrlEncode(signature.bytes);
  }

  Future<bool> verify({
    required String payload,
    required String signature,
    required String publicKey,
  }) async {
    final result = await _algorithm.verify(
      Uint8List.fromList(convert.utf8.encode(payload)),
      signature: Signature(
        convert.base64Url.decode(signature),
        publicKey: SimplePublicKey(
          convert.base64Url.decode(publicKey),
          type: KeyPairType.ed25519,
        ),
      ),
    );

    return result;
  }
}
