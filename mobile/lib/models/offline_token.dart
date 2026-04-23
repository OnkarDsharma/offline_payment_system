class OfflineToken {
  const OfflineToken({
    required this.id,
    required this.ownerUserId,
    required this.amount,
    required this.status,
    required this.signature,
    required this.issuedAt,
    this.spentAt,
    this.redeemedAt,
  });

  final String id;
  final String ownerUserId;
  final double amount;
  final String status;
  final String signature;
  final String issuedAt;
  final String? spentAt;
  final String? redeemedAt;

  factory OfflineToken.fromApiMap(Map<String, dynamic> map) {
    return OfflineToken(
      id: (map['id'] ?? '').toString(),
      ownerUserId: (map['ownerUserId'] ?? '').toString(),
      amount: (map['amount'] as num? ?? 0).toDouble(),
      status: (map['status'] ?? '').toString(),
      signature: (map['signature'] ?? '').toString(),
      issuedAt: (map['issuedAt'] ?? '').toString(),
      spentAt: map['spentAt']?.toString(),
      redeemedAt: map['redeemedAt']?.toString(),
    );
  }

  Map<String, dynamic> toRedeemPayloadMap() {
    return {
      'id': id,
      'ownerUserId': ownerUserId,
      'amount': amount,
      'signature': signature,
      'issuedAt': issuedAt,
    };
  }
}
