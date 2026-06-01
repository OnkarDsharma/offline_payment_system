String buildOfflineTransactionCanonicalString({
  required String transactionId,
  required String fromUserId,
  required String toUserId,
  required int amount,
  required String currency,
  required String timestamp,
}) {
  return [
    transactionId,
    fromUserId,
    toUserId,
    amount.toString(),
    currency,
    timestamp,
  ].join('|');
}
