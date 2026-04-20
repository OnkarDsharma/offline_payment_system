import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/transaction_tile.dart';
import '../providers/prototype_wallet_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prototypeWalletProvider);
    final transactions = state.transactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Prototype Transaction History')),
      body: transactions.isEmpty
          ? const Center(child: Text('No transactions found.'))
          : ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return TransactionTile(
                  transaction: transactions[index],
                  currentUserId: transactions[index].fromUserId,
                );
              },
            ),
    );
  }
}