import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/offline_token.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/money.dart';

class OfflineTokensScreen extends ConsumerStatefulWidget {
  const OfflineTokensScreen({super.key});

  @override
  ConsumerState<OfflineTokensScreen> createState() =>
      _OfflineTokensScreenState();
}

class _OfflineTokensScreenState extends ConsumerState<OfflineTokensScreen> {
  final _amountController = TextEditingController(text: '100');

  bool _converting = false;
  List<OfflineToken> _localConversions = const [];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _convertOnlineToOffline() async {
    final session = ref.read(authSessionProvider);
    final wallet = ref.read(walletProvider);

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet session is not ready yet.')),
      );
      return;
    }

    final amountRupees = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amountRupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount in rupees.')),
      );
      return;
    }

    final amountPaise = (amountRupees * 100).round();
    if (wallet.onlineBalance < amountPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient online balance.')),
      );
      return;
    }

    setState(() {
      _converting = true;
    });

    try {
      final updatedWallet = wallet.copyWith(
        onlineBalance: wallet.onlineBalance - amountPaise,
        offlineBalance: wallet.offlineBalance + amountPaise,
      );

      await ref.read(databaseHelperProvider).saveWallet(updatedWallet);
      ref.read(walletProvider.notifier).state = updatedWallet;

      final conversion = OfflineToken(
        id: 'conversion_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
        ownerUserId: session.userId,
        amount: amountRupees,
        status: 'CONVERTED_FOR_TEST',
        signature: 'LOCAL_CONVERSION',
        issuedAt: DateTime.now().toUtc().toIso8601String(),
      );

      setState(() {
        _localConversions = [conversion, ..._localConversions];
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Converted ${formatPaise(amountPaise)} from online to offline balance.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _converting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ConvertHeader(onBack: () => Navigator.of(context).pop()),
            const SizedBox(height: 14),
            const _InfoCard(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _BalanceTile(
                    title: 'Online balance',
                    value: formatPaise(wallet.onlineBalance),
                    icon: Icons.cloud_done_rounded,
                    color: const Color(0xFF007A52),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BalanceTile(
                    title: 'Offline balance',
                    value: formatPaise(wallet.offlineBalance),
                    icon: Icons.offline_bolt_rounded,
                    color: const Color(0xFF7347D9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFEEF1EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Convert amount',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF0A2E20),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Move value from online balance into offline spending power.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF687A72),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount in rupees',
                      prefixText: 'Rs. ',
                      helperText: 'Example: enter 100 to move Rs. 100.00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _converting ? null : _convertOnlineToOffline,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(
                        _converting
                            ? 'Converting...'
                            : 'Convert to Offline Balance',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Test Conversions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0A2E20),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            if (_localConversions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEEF1EA)),
                ),
                child: Text(
                  'No conversions yet. Convert an amount above to test the new balance flow.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687A72),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              )
            else
              ..._localConversions.map(
                (conversion) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFEEF1EA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF6F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFF007A52),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Moved Rs. ${conversion.amount.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: const Color(0xFF0A2E20),
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              conversion.issuedAt,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF687A72),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(label: conversion.status),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConvertHeader extends StatelessWidget {
  const _ConvertHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B28), Color(0xFF007A52)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Convert Balance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Prepare offline tokens for QR payments',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBFF7D8),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFC7FF18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.offline_bolt_rounded, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA9ECE4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF075A3D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_card_rounded, color: Color(0xFFC7FF18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This test flow moves value from online balance into offline balance locally so you can try offline payments before full server sync is finalized.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF073B2A),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF0A2E20),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF0A2E20),
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF6F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF007A52),
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}
