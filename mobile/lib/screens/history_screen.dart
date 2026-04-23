import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/transaction_tile.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: transactions.isEmpty
          ? const Center(child: Text('No transactions found.'))
          : ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return TransactionTile(
                  transaction: transactions[index],
                  currentUserId: session?.userId ?? '',
                );
              },
            ),
    );
  }
}