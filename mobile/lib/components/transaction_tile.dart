import 'package:flutter/material.dart';

import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currentUserId,
  });

  final WalletTransaction transaction;
  final String currentUserId;

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
      case TransactionStatus.confirmed:
        return Colors.green;
      case TransactionStatus.failed:
      case TransactionStatus.rejected:
        return Colors.red;
      case TransactionStatus.pendingSync:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = transaction.fromUserId == currentUserId;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isOutgoing ? Colors.red.shade100 : Colors.green.shade100,
        child: Icon(
          isOutgoing ? Icons.call_made : Icons.call_received,
          color: isOutgoing ? Colors.red : Colors.green,
        ),
      ),
      title: Text('${isOutgoing ? 'Sent' : 'Received'} Rs. ${transaction.amount.toStringAsFixed(2)}'),
      subtitle: Text(
        '${transaction.fromUserId.substring(0, 8)} -> ${transaction.toUserId.substring(0, 8)}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _statusColor(transaction.status).withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          transaction.status.name.toUpperCase(),
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