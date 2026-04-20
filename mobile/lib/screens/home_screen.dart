import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/balance_card.dart';
import '../components/transaction_tile.dart';
import '../providers/prototype_wallet_provider.dart';
import 'history_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prototypeWalletProvider);
    final wallet = state.wallet;
    final transactions = state.transactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Wallet Prototype'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'This Device Wallet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BalanceCard(
              title: wallet.name,
              amount: wallet.balance,
              color: Colors.teal,
              subtitle: 'Wallet ID: ${wallet.id}',
            ),
          ),
          const Text(
            'Demo flow with 2 phones: Phone A generates request QR -> Phone B scans and pays -> Phone B shows confirmation QR -> Phone A scans confirmation.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Receive'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SendScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            icon: const Icon(Icons.history),
            label: const Text('View Transaction History'),
          ),
          const SizedBox(height: 20),
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No transactions yet. Generate a payment QR and scan it.'),
            )
          else
            ...transactions.take(3).map(
                  (tx) => TransactionTile(
                    transaction: tx,
                    currentUserId: wallet.id,
                  ),
                ),
        ],
      ),
    );
  }
}