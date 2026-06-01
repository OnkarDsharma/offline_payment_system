class PaymentRequest {
  const PaymentRequest({
    required this.qrType,
    required this.toUserId,
    required this.toPublicKey,
    required this.amount,
    required this.expiresAt,
  });

  final String qrType;
  final String toUserId;
  final String toPublicKey;
  final int amount;
  final String expiresAt;

  DateTime get expiresAtUtc => DateTime.parse(expiresAt).toUtc();

  factory PaymentRequest.fromJson(Map<String, dynamic> json) {
    return PaymentRequest(
      qrType: (json['qr_type'] ?? '').toString(),
      toUserId: (json['to_user_id'] ?? '').toString(),
      toPublicKey: (json['to_public_key'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0).toInt(),
      expiresAt: (json['expires_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qr_type': qrType,
      'to_user_id': toUserId,
      'to_public_key': toPublicKey,
      'amount': amount,
      'expires_at': expiresAt,
    };
  }
}
