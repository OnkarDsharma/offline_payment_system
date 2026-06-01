import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../crypto/signer.dart';
import '../models/payment_request.dart';
import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/sync_service.dart';
import '../utils/money.dart';
import '../utils/time.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _amountController = TextEditingController();
  final _signer = Signer();
  final _uuid = const Uuid();

  PaymentRequest? _paymentRequest;
  WalletTransaction? _transaction;
  String? _error;
  bool _scannedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanRequestQr());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scanRequestQr() async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _ScannerScreen(title: 'Scan Payment Request QR'),
      ),
    );

    if (!mounted || payload == null) {
      return;
    }

    _scannedOnce = true;
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final request = PaymentRequest.fromJson(parsed);
      if (request.qrType != 'PAYMENT_REQUEST') {
        throw const FormatException('QR is not a payment request.');
      }
      if (DateTime.now().toUtc().isAfter(request.expiresAtUtc)) {
        throw const FormatException('Payment request QR has expired.');
      }

      setState(() {
        _paymentRequest = request;
        _amountController.text = request.amount == 0
            ? ''
            : formatPaiseAsEditableRupees(request.amount);
        _error = null;
        _transaction = null;
      });
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _confirmPayment() async {
    final session = ref.read(authSessionProvider);
    final wallet = ref.read(walletProvider);
    final keyPair = await ref.read(keyManagerProvider).ensureKeyPair();

    if (session == null || _paymentRequest == null) {
      setState(() {
        _error = 'Scan a valid payment request first.';
      });
      return;
    }

    final amount = parseRupeesToPaise(_amountController.text) ?? -1;
    if (amount <= 0) {
      setState(() {
        _error = 'Enter a valid amount in rupees.';
      });
      return;
    }
    if (wallet.offlineBalance < amount) {
      setState(() {
        _error = 'Insufficient offline balance.';
      });
      return;
    }

    final timestamp = utcIsoTimestamp(DateTime.now().toUtc());
    final transaction = WalletTransaction(
      transactionId: _uuid.v4(),
      fromUserId: session.userId,
      toUserId: _paymentRequest!.toUserId,
      amount: amount,
      currency: 'INR',
      timestamp: timestamp,
      fromPublicKey: keyPair.publicKey,
      signature: '',
      direction: OfflineTransactionDirection.sent,
      status: OfflineTransactionStatus.pendingSync,
      createdAt: timestamp,
    );

    final signature = await _signer.sign(
      payload: transaction.canonicalString,
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
    );

    final signedTransaction = WalletTransaction(
      transactionId: transaction.transactionId,
      fromUserId: transaction.fromUserId,
      toUserId: transaction.toUserId,
      amount: transaction.amount,
      currency: transaction.currency,
      timestamp: transaction.timestamp,
      fromPublicKey: transaction.fromPublicKey,
      signature: signature,
      direction: transaction.direction,
      status: transaction.status,
      createdAt: transaction.createdAt,
    );

    final db = ref.read(databaseHelperProvider);
    await db.upsertOfflineTransaction(signedTransaction);
    await db.updateWalletBalances(
      userId: session.userId,
      offlineBalance: wallet.offlineBalance - amount,
    );

    ref.read(walletProvider.notifier).state = wallet.copyWith(
      offlineBalance: wallet.offlineBalance - amount,
    );
    ref.read(transactionsProvider.notifier).state = await db.getTransactions();

    setState(() {
      _transaction = signedTransaction;
      _error = null;
    });

    await ref.read(syncServiceProvider).syncIfOnline();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEE),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _ScreenHeader(
              title: 'Send Offline',
              subtitle: 'Scan a request and create a signed payment QR.',
              icon: Icons.qr_code_scanner_rounded,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            _BalanceHero(
              label: 'Offline balance',
              amount: formatPaise(wallet.offlineBalance),
              icon: Icons.offline_bolt_rounded,
            ),
            const SizedBox(height: 12),
            _ActionPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelTitle(
                    title: 'Payment request',
                    subtitle: _paymentRequest == null
                        ? 'Scan the receiver request QR to begin.'
                        : 'Sending to ${_paymentRequest!.toUserId}',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _scanRequestQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan Request QR'),
                    ),
                  ),
                  if (_paymentRequest != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount in rupees',
                        prefixText: 'Rs. ',
                      ),
                      enabled: _paymentRequest!.amount == 0,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirmPayment,
                        child: Builder(builder: (_) {
                          final displayedPaise =
                              parseRupeesToPaise(_amountController.text) ?? 0;
                          return Text('Send ${formatPaise(displayedPaise)}');
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_transaction != null) ...[
              const SizedBox(height: 12),
              _ActionPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelTitle(
                      title: 'Confirmation QR',
                      subtitle: 'Show this to the receiver to finish payment.',
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
                          data:
                              jsonEncode(_transaction!.toConfirmationQrJson()),
                          size: 220,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _InfoStrip(
                      icon: Icons.sync_rounded,
                      text:
                          'Waiting for sync after the receiver scans this QR.',
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(
                text: _error!,
                isError: true,
              ),
            ],
            if (!_scannedOnce) ...[
              const SizedBox(height: 12),
              const _InfoStrip(
                icon: Icons.photo_camera_rounded,
                text:
                    'Camera opens immediately so you can scan the receiver request QR.',
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
                  'Place the QR code inside the camera frame.',
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

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.label,
    required this.amount,
    required this.icon,
  });

  final String label;
  final String amount;
  final IconData icon;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  amount.replaceFirst('Rs.', 'Rs.'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.62),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: Icon(icon, color: const Color(0xFF007A52)),
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

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF007A52)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4E4E4E),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
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
