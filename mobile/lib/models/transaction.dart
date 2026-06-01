import '../crypto/offline_crypto.dart';

enum OfflineTransactionStatus {
  pendingSync,
  confirmed,
  rejected,
}

enum OfflineTransactionDirection {
  sent,
  received,
}

OfflineTransactionStatus offlineTransactionStatusFromString(String rawStatus) {
  switch (rawStatus.trim().toUpperCase()) {
    case 'PENDING_SYNC':
      return OfflineTransactionStatus.pendingSync;
    case 'CONFIRMED':
      return OfflineTransactionStatus.confirmed;
    case 'REJECTED':
      return OfflineTransactionStatus.rejected;
    default:
      throw ArgumentError('Unknown transaction status: $rawStatus');
  }
}

OfflineTransactionDirection offlineTransactionDirectionFromString(
    String rawDirection) {
  switch (rawDirection.trim().toUpperCase()) {
    case 'SENT':
      return OfflineTransactionDirection.sent;
    case 'RECEIVED':
      return OfflineTransactionDirection.received;
    default:
      throw ArgumentError('Unknown transaction direction: $rawDirection');
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.transactionId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.currency,
    required this.timestamp,
    required this.fromPublicKey,
    required this.signature,
    required this.direction,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
  });

  final String transactionId;
  final String fromUserId;
  final String toUserId;
  final int amount;
  final String currency;
  final String timestamp;
  final String fromPublicKey;
  final String signature;
  final OfflineTransactionDirection direction;
  final OfflineTransactionStatus status;
  final String createdAt;
  final String? rejectionReason;

  String get canonicalString => buildOfflineTransactionCanonicalString(
        transactionId: transactionId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        amount: amount,
        currency: currency,
        timestamp: timestamp,
      );

  DateTime get timestampUtc => DateTime.parse(timestamp).toUtc();

  factory WalletTransaction.fromApiMap(Map<String, dynamic> map) {
    return WalletTransaction(
      transactionId: (map['transaction_id'] ?? map['id'] ?? '').toString(),
      fromUserId: (map['from_user_id'] ??
              map['sender_user_id'] ??
              map['senderUserId'] ??
              '')
          .toString(),
      toUserId: (map['to_user_id'] ??
              map['receiver_user_id'] ??
              map['receiverUserId'] ??
              '')
          .toString(),
      amount: (map['amount'] as num? ?? 0).toInt(),
      currency: (map['currency'] ?? 'INR').toString(),
      timestamp: (map['timestamp'] ??
              map['device_timestamp'] ??
              map['createdAt'] ??
              '')
          .toString(),
      fromPublicKey: (map['from_public_key'] ?? '').toString(),
      signature: (map['signature'] ?? '').toString(),
      direction: offlineTransactionDirectionFromString(
          (map['direction'] ?? 'SENT').toString()),
      status: offlineTransactionStatusFromString(
          (map['status'] ?? 'PENDING_SYNC').toString()),
      rejectionReason: map['rejection_reason']?.toString(),
      createdAt: (map['created_at'] ?? map['createdAt'] ?? '').toString(),
    );
  }

  factory WalletTransaction.fromDbMap(Map<String, Object?> map) {
    return WalletTransaction(
      transactionId: map['transaction_id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      amount: (map['amount'] as num).toInt(),
      currency: map['currency'] as String,
      timestamp: map['timestamp'] as String,
      fromPublicKey: map['from_public_key'] as String,
      signature: map['signature'] as String,
      direction:
          offlineTransactionDirectionFromString(map['direction'] as String),
      status: offlineTransactionStatusFromString(map['status'] as String),
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'currency': currency,
      'timestamp': timestamp,
      'from_public_key': fromPublicKey,
      'signature': signature,
    };
  }

  Map<String, dynamic> toConfirmationQrJson() {
    return {
      'qr_type': 'PAYMENT_CONFIRMATION',
      ...toJson(),
    };
  }

  Map<String, Object?> toDbMap() {
    return {
      'transaction_id': transactionId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'amount': amount,
      'currency': currency,
      'timestamp': timestamp,
      'from_public_key': fromPublicKey,
      'signature': signature,
      'direction': direction.name.toUpperCase(),
      'status': _statusToDbValue(status),
      'rejection_reason': rejectionReason,
      'created_at': createdAt,
    };
  }

  WalletTransaction copyWith({
    OfflineTransactionStatus? status,
    String? rejectionReason,
  }) {
    return WalletTransaction(
      transactionId: transactionId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      currency: currency,
      timestamp: timestamp,
      fromPublicKey: fromPublicKey,
      signature: signature,
      direction: direction,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
    );
  }

  static String _statusToDbValue(OfflineTransactionStatus status) {
    switch (status) {
      case OfflineTransactionStatus.pendingSync:
        return 'PENDING_SYNC';
      case OfflineTransactionStatus.confirmed:
        return 'CONFIRMED';
      case OfflineTransactionStatus.rejected:
        return 'REJECTED';
    }
  }
}
