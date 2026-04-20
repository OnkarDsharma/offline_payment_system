import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/prototype_wallet_provider.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  final _walletNameController = TextEditingController();
  final _amountController = TextEditingController(text: '200');
  final _confirmationPayloadController = TextEditingController();
  String? _requestQrPayload;

  @override
  void dispose() {
    _walletNameController.dispose();
    _amountController.dispose();
    _confirmationPayloadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prototypeWalletProvider);
    final wallet = state.wallet;

    if (_walletNameController.text.isEmpty) {
      _walletNameController.text = wallet.name;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _walletNameController,
              decoration: const InputDecoration(
                labelText: 'This wallet name (for demo)',
              ),
              onSubmitted: (value) {
                ref.read(prototypeWalletProvider.notifier).updateWalletName(value);
              },
            ),
            const SizedBox(height: 12),
            SelectableText('Wallet ID: ${wallet.id}'),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Request Amount'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount.')),
                  );
                  return;
                }

                ref.read(prototypeWalletProvider.notifier).updateWalletName(_walletNameController.text);

                final payload = ref
                    .read(prototypeWalletProvider.notifier)
                    .generatePaymentRequest(amount: amount);

                setState(() {
                  _requestQrPayload = payload;
                });
              },
              child: const Text('Generate Request QR'),
            ),
            const SizedBox(height: 16),
            if (_requestQrPayload != null) ...[
              const Text('Phone B (sender) scans this request QR:'),
              const SizedBox(height: 10),
              Center(
                child: QrImageView(
                  data: _requestQrPayload!,
                  size: 240,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(jsonDecode(_requestQrPayload!)),
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            const Text('Step 2: Scan sender confirmation QR to receive balance'),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final payload = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const _ScannerScreen(title: 'Scan Sender Confirmation QR'),
                  ),
                );

                if (payload != null) {
                  _confirmationPayloadController.text = payload;
                  final message = await ref
                      .read(prototypeWalletProvider.notifier)
                      .applyIncomingConfirmation(confirmationPayload: payload);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Confirmation QR'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmationPayloadController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Or paste confirmation payload',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final message = await ref
                    .read(prototypeWalletProvider.notifier)
                    .applyIncomingConfirmation(
                      confirmationPayload: _confirmationPayloadController.text,
                    );
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
              },
              child: const Text('Apply Confirmation'),
            ),
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
