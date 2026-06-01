import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../utils/money.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currentUserId,
  });

  final WalletTransaction transaction;
  final String currentUserId;

  Color _statusColor(OfflineTransactionStatus status) {
    switch (status) {
      case OfflineTransactionStatus.confirmed:
        return Colors.green;
      case OfflineTransactionStatus.rejected:
        return Colors.red;
      case OfflineTransactionStatus.pendingSync:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = transaction.fromUserId == currentUserId;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            isOutgoing ? Colors.red.shade100 : Colors.green.shade100,
        child: Icon(
          isOutgoing ? Icons.call_made : Icons.call_received,
          color: isOutgoing ? Colors.red : Colors.green,
        ),
      ),
      title: Text(
          '${isOutgoing ? 'Sent' : 'Received'} ${formatPaise(transaction.amount)}'),
      subtitle: Text(
        '${transaction.fromUserId} -> ${transaction.toUserId}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(transaction.status).withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          switch (transaction.status) {
            OfflineTransactionStatus.pendingSync => 'PENDING_SYNC',
            OfflineTransactionStatus.confirmed => 'CONFIRMED',
            OfflineTransactionStatus.rejected => 'REJECTED',
          },
          style: TextStyle(
            color: _statusColor(transaction.status),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
