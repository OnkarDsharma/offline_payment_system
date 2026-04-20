enum TransactionStatus {
  pendingSync,
  confirmed,
  rejected,
  completed,
  failed,
}

TransactionStatus transactionStatusFromString(String rawStatus) {
  switch (rawStatus.trim().toUpperCase()) {
    case 'PENDING_SYNC':
      return TransactionStatus.pendingSync;
    case 'CONFIRMED':
      return TransactionStatus.confirmed;
    case 'REJECTED':
      return TransactionStatus.rejected;
    case 'COMPLETED':
      return TransactionStatus.completed;
    case 'FAILED':
      return TransactionStatus.failed;
    default:
      return TransactionStatus.failed;
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.timestamp,
    required this.status,
    this.signature,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime timestamp;
  final TransactionStatus status;
  final String? signature;

  factory WalletTransaction.fromApiMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: (map['id'] ?? '').toString(),
      fromUserId: (map['senderUserId'] ?? '').toString(),
      toUserId: (map['receiverUserId'] ?? '').toString(),
      amount: (map['amount'] as num? ?? 0).toDouble(),
      timestamp: DateTime.parse((map['createdAt'] ?? DateTime.now().toIso8601String()).toString()),
      status: transactionStatusFromString((map['status'] ?? 'FAILED').toString()),
      signature: map['signature']?.toString(),
    );
  }

  factory WalletTransaction.fromDbMap(Map<String, Object?> map) {
    return WalletTransaction(
      id: map['id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: transactionStatusFromString(map['status'] as String),
      signature: map['signature'] as String?,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name.toUpperCase(),
      'signature': signature,
    };
  }
}