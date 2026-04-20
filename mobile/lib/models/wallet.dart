class Wallet {
  const Wallet({
    required this.onlineBalance,
    required this.offlineBalance,
  });

  final double onlineBalance;
  final double offlineBalance;

  factory Wallet.fromApiMap(Map<String, dynamic> map) {
    return Wallet(
      onlineBalance: (map['onlineBalance'] as num? ?? 0).toDouble(),
      offlineBalance: (map['offlineBalance'] as num? ?? 0).toDouble(),
    );
  }

  factory Wallet.fromDbMap(Map<String, Object?> map) {
    return Wallet(
      onlineBalance: (map['online_balance'] as num).toDouble(),
      offlineBalance: (map['offline_balance'] as num).toDouble(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': 1,
      'online_balance': onlineBalance,
      'offline_balance': offlineBalance,
    };
  }
}