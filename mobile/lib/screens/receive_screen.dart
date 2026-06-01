import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../crypto/signer.dart';
import '../models/payment_request.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/sync_service.dart';
import '../utils/money.dart';
import '../utils/time.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  final _amountController = TextEditingController(text: '0.00');
  final _signer = Signer();

  PaymentRequest? _paymentRequest;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  String? _statusMessage;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _generateQr() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      _showError('Wallet session is not ready yet.');
      return;
    }

    final amount = parseRupeesToPaise(_amountController.text) ?? -1;
    if (amount < 0) {
      _showError('Enter a valid amount in rupees.');
      return;
    }

    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final request = PaymentRequest(
      qrType: 'PAYMENT_REQUEST',
      toUserId: session.userId,
      toPublicKey: session.publicKey,
      amount: amount,
      expiresAt: utcIsoTimestamp(expiresAt),
    );

    setState(() {
      _paymentRequest = request;
      _statusMessage = null;
      _remaining = expiresAt.difference(DateTime.now().toUtc());
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paymentRequest == null) {
        return;
      }
      final next =
          _paymentRequest!.expiresAtUtc.difference(DateTime.now().toUtc());
      if (next.isNegative) {
        setState(() {
          _paymentRequest = null;
          _remaining = Duration.zero;
          _statusMessage = 'Request QR expired. Generate a fresh one.';
        });
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _remaining = next;
      });
    });
  }

  Future<void> _scanConfirmationQr() async {
    if (_paymentRequest == null) {
      _showError('Generate a payment request before scanning confirmation.');
      return;
    }

    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            const _ScannerScreen(title: 'Scan Sender Confirmation QR'),
      ),
    );

    if (payload != null) {
      await _handleConfirmationPayload(payload);
    }
  }

  Future<void> _handleConfirmationPayload(String payload) async {
    final session = ref.read(authSessionProvider);
    final wallet = ref.read(walletProvider);
    if (session == null || _paymentRequest == null) {
      _showError('Generate a payment request before scanning confirmation.');
      return;
    }

    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      if ((parsed['qr_type'] ?? '').toString() != 'PAYMENT_CONFIRMATION') {
        throw const FormatException('QR is not a payment confirmation.');
      }

      final transaction = WalletTransaction(
        transactionId: (parsed['transaction_id'] ?? '').toString(),
        fromUserId: (parsed['from_user_id'] ?? '').toString(),
        toUserId: (parsed['to_user_id'] ?? '').toString(),
        amount: (parsed['amount'] as num? ?? 0).toInt(),
        currency: (parsed['currency'] ?? 'INR').toString(),
        timestamp: (parsed['timestamp'] ?? '').toString(),
        fromPublicKey: (parsed['from_public_key'] ?? '').toString(),
        signature: (parsed['signature'] ?? '').toString(),
        direction: OfflineTransactionDirection.received,
        status: OfflineTransactionStatus.pendingSync,
        createdAt: utcIsoTimestamp(DateTime.now().toUtc()),
      );

      if (transaction.toUserId != session.userId) {
        throw const FormatException('This payment was meant for another user.');
      }
      if (_paymentRequest!.amount > 0 &&
          transaction.amount != _paymentRequest!.amount) {
        throw const FormatException(
            'Amount does not match the requested amount.');
      }

      final age =
          DateTime.now().toUtc().difference(transaction.timestampUtc).abs();
      if (age > const Duration(minutes: 2)) {
        throw const FormatException('Confirmation QR is too old.');
      }

      final existing = await ref
          .read(databaseHelperProvider)
          .getTransactionById(transaction.transactionId);
      if (existing != null) {
        throw const FormatException(
            'This transaction has already been scanned.');
      }

      final isValid = await _signer.verify(
        payload: transaction.canonicalString,
        signature: transaction.signature,
        publicKey: transaction.fromPublicKey,
      );

      if (!isValid) {
        throw const FormatException('Signature verification failed.');
      }

      final db = ref.read(databaseHelperProvider);
      await db.upsertOfflineTransaction(transaction);
      await db.updateWalletBalances(
        userId: session.userId,
        offlineBalance: wallet.offlineBalance + transaction.amount,
      );

      ref.read(walletProvider.notifier).state = wallet.copyWith(
        offlineBalance: wallet.offlineBalance + transaction.amount,
      );
      ref.read(transactionsProvider.notifier).state =
          await db.getTransactions();
      _statusMessage =
          'Received ${formatPaise(transaction.amount)} offline. Pending sync.';
      setState(() {
        _paymentRequest = null;
      });

      await ref.read(syncServiceProvider).syncIfOnline();
    } catch (error) {
      _showError(error.toString().replaceFirst('FormatException: ', ''));
    }
  }

  void _showError(String message) {
    setState(() {
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEE),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ScreenHeader(
              title: 'Receive Offline',
              subtitle: 'Generate a request QR and scan confirmation.',
              icon: Icons.qr_code_2_rounded,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            _ReceiverCard(
              name: session?.name ?? 'Loading...',
              userId: session?.userId ?? 'not-ready',
            ),
            const SizedBox(height: 12),
            _ActionPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PanelTitle(
                    title: 'Request amount',
                    subtitle: 'Use 0 to let the sender enter the amount.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Requested amount in rupees',
                      prefixText: 'Rs. ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _generateQr,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Generate QR'),
                    ),
                  ),
                ],
              ),
            ),
            if (_paymentRequest != null) ...[
              const SizedBox(height: 12),
              _ActionPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PanelTitle(
                      title: 'Payment request QR',
                      subtitle:
                          'Expires in ${_remaining.inMinutes}:${(_remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE6E6E6)),
                        ),
                        child: QrImageView(
                          data: jsonEncode(_paymentRequest!.toJson()),
                          size: 220,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _scanConfirmationQr,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan Confirmation QR'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(
                text: _statusMessage!,
                isError: !_statusMessage!.startsWith('Received '),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen({required this.title});

  final String title;

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: MobileScanner(
                onDetect: (capture) {
                  if (_handled) {
                    return;
                  }
                  final value = capture.barcodes.first.rawValue;
                  if (value == null || value.isEmpty) {
                    return;
                  }
                  _handled = true;
                  Navigator.of(context).pop(value);
                },
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 14,
              child: _ScannerTopBar(title: widget.title),
            ),
            Positioned(
              left: 34,
              right: 34,
              bottom: 34,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Place the confirmation QR inside the camera frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final IconData icon;
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
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
            child: Icon(icon, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _ReceiverCard extends StatelessWidget {
  const _ReceiverCard({
    required this.name,
    required this.userId,
  });

  final String name;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFC7FF18),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: Color(0xFF007A52)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receiver',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  userId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF303030),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF626262),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.text,
    this.isError = false,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFE8E3) : const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color:
                  isError ? const Color(0xFFB3261E) : const Color(0xFF007A52),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ScannerTopBar extends StatelessWidget {
  const _ScannerTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.54),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
