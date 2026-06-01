import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/money.dart';

class OnlinePaymentScreen extends ConsumerStatefulWidget {
  const OnlinePaymentScreen({super.key});

  @override
  ConsumerState<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends ConsumerState<OnlinePaymentScreen> {
  final _receiverController = TextEditingController();
  final _amountController = TextEditingController(text: '100.00');
  bool _sending = false;

  @override
  void dispose() {
    _receiverController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _sendOnlinePayment() async {
    final session = ref.read(authSessionProvider);
    final mode = ref.read(appModeProvider);
    if (session == null || session.token.isEmpty || mode != AppMode.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Online payments require server connectivity.')),
      );
      return;
    }

    final amountPaise = parseRupeesToPaise(_amountController.text) ?? -1;
    final receiverUserId = _receiverController.text.trim();
    if (receiverUserId.isEmpty || amountPaise <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter receiver user ID and a valid rupee amount.')),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await ref.read(apiServiceProvider).createTransfer(
            token: session.token,
            receiverUserId: receiverUserId,
            amount: amountPaise,
          );

      ref.invalidate(walletBootstrapProvider);
      ref.invalidate(transactionsBootstrapProvider);
      await ref.read(walletBootstrapProvider.future);
      await ref.read(transactionsBootstrapProvider.future);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent ${formatPaise(amountPaise)} online.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Online payment failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Online Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDBEAFE), Color(0xFFF8FAFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Online payment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send server-backed money instantly while your laptop backend is reachable.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available online',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            formatPaise(wallet.onlineBalance),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _receiverController,
            decoration: const InputDecoration(
              labelText: 'Receiver User ID',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount in rupees',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _sendOnlinePayment,
            icon: const Icon(Icons.cloud_upload),
            label: Text(_sending ? 'Sending...' : 'Send Online Payment'),
          ),
        ],
      ),
    );
  }
}
