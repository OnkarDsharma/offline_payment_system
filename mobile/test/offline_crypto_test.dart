import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/crypto/offline_crypto.dart';
import 'package:offline_wallet/crypto/signer.dart';

String _hexToBase64Url(String hex) {
  final bytes = <int>[];
  for (var index = 0; index < hex.length; index += 2) {
    bytes.add(int.parse(hex.substring(index, index + 2), radix: 16));
  }
  return base64UrlEncode(bytes);
}

void main() {
  const transactionId = '550e8400-e29b-41d4-a716-446655440000';
  const fromUserId = 'prachi_456';
  const toUserId = 'raj_123';
  const amount = 20000;
  const currency = 'INR';
  const timestamp = '2024-03-27T10:00:01Z';

  test('builds the exact canonical string', () {
    final canonical = buildOfflineTransactionCanonicalString(
      transactionId: transactionId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      currency: currency,
      timestamp: timestamp,
    );

    expect(
      canonical,
      '550e8400-e29b-41d4-a716-446655440000|prachi_456|raj_123|20000|INR|2024-03-27T10:00:01Z',
    );
  });

  test('signs and verifies using Ed25519 and fails after tampering', () async {
    final signer = Signer();
    final canonical = buildOfflineTransactionCanonicalString(
      transactionId: transactionId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      currency: currency,
      timestamp: timestamp,
    );

    const privateKeyHex =
        '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';
    const publicKeyHex =
        'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';

    final signature = await signer.sign(
      payload: canonical,
      privateKey: _hexToBase64Url(privateKeyHex),
      publicKey: _hexToBase64Url(publicKeyHex),
    );

    final isValid = await signer.verify(
      payload: canonical,
      signature: signature,
      publicKey: _hexToBase64Url(publicKeyHex),
    );

    final isTamperedValid = await signer.verify(
      payload: '${canonical}X',
      signature: signature,
      publicKey: _hexToBase64Url(publicKeyHex),
    );

    expect(isValid, isTrue);
    expect(isTamperedValid, isFalse);
  });
}
