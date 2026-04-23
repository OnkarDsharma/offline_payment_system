import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _requestPayloadController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _requestPayloadController.dispose();
    super.dispose();
  }

  Future<void> _processRequestPayload(String payload) async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet session is not ready yet.')),
      );
      return;
    }

    if (payload.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan or paste a request QR payload.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final receiverUserId = (parsed['receiverUserId'] ?? '').toString();
      final amount = (parsed['amount'] as num?)?.toDouble() ?? 0;

      if (receiverUserId.isEmpty || amount <= 0) {
        throw const FormatException('Invalid payment request payload.');
      }

      await ref.read(apiServiceProvider).createTransfer(
            token: session.token,
            receiverUserId: receiverUserId,
            amount: amount,
          );

      ref.invalidate(walletBootstrapProvider);
      ref.invalidate(transactionsBootstrapProvider);
      await ref.read(walletBootstrapProvider.future);
      await ref.read(transactionsBootstrapProvider.future);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment sent: Rs. ${amount.toStringAsFixed(2)}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send payment: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final wallet = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Send Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Sender: ${session?.name ?? 'Loading...'}'),
            const SizedBox(height: 4),
            Text('User ID: ${session?.userId ?? 'not-ready'}'),
            const SizedBox(height: 4),
            Text('Online balance: Rs. ${wallet.onlineBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _requestPayloadController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Request QR payload (scan or paste)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () async {
                final payload = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const _ScannerScreen(title: 'Scan Receiver Request QR'),
                  ),
                );

                if (payload != null) {
                  _requestPayloadController.text = payload;
                  await _processRequestPayload(payload);
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Request QR'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed:
                  _isSubmitting ? null : () => _processRequestPayload(_requestPayloadController.text),
              child: Text(_isSubmitting ? 'Processing...' : 'Pay Via Backend'),
            ),
            const SizedBox(height: 16),
            if (_requestPayloadController.text.trim().isNotEmpty) ...[
              const Text('Parsed Request Preview'),
              const SizedBox(height: 8),
              _RequestPreview(payload: _requestPayloadController.text),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestPreview extends StatelessWidget {
  const _RequestPreview({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final receiver = (parsed['receiverUserId'] ?? '').toString();
      final amount = (parsed['amount'] ?? '').toString();
      return Text('Receiver User ID: $receiver\nAmount: Rs. $amount');
    } catch (_) {
      return const Text('Unable to parse request payload yet.');
    }
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
      appBar: AppBar(title: Text(widget.title)),
      body: MobileScanner(
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
    );
  }
}
