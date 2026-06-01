class Wallet {
  const Wallet({
    required this.userId,
    required this.onlineBalance,
    required this.offlineBalance,
    this.lastSyncedAt,
  });

  final String userId;
  final int onlineBalance;
  final int offlineBalance;
  final String? lastSyncedAt;

  factory Wallet.fromApiMap(Map<String, dynamic> map) {
    return Wallet(
      userId: (map['userId'] ?? map['user_id'] ?? '').toString(),
      onlineBalance:
          (map['onlineBalance'] as num? ?? map['online_balance'] as num? ?? 0)
              .toInt(),
      offlineBalance:
          (map['offlineBalance'] as num? ?? map['offline_balance'] as num? ?? 0)
              .toInt(),
      lastSyncedAt:
          map['lastSyncedAt']?.toString() ?? map['last_synced_at']?.toString(),
    );
  }

  factory Wallet.fromDbMap(Map<String, Object?> map) {
    return Wallet(
      userId: map['user_id'] as String,
      onlineBalance: (map['online_balance'] as num).toInt(),
      offlineBalance: (map['offline_balance'] as num).toInt(),
      lastSyncedAt: map['last_synced_at'] as String?,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'user_id': userId,
      'online_balance': onlineBalance,
      'offline_balance': offlineBalance,
      'last_synced_at': lastSyncedAt,
    };
  }

  Wallet copyWith({
    String? userId,
    int? onlineBalance,
    int? offlineBalance,
    String? lastSyncedAt,
  }) {
    return Wallet(
      userId: userId ?? this.userId,
      onlineBalance: onlineBalance ?? this.onlineBalance,
      offlineBalance: offlineBalance ?? this.offlineBalance,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
