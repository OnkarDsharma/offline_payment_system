import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/prototype_wallet_provider.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _requestPayloadController = TextEditingController();
  String? _confirmationPayload;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _requestPayloadController.dispose();
    super.dispose();
  }

  Future<void> _processRequestPayload(String payload) async {
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
      final result = await ref
          .read(prototypeWalletProvider.notifier)
          .createOutgoingConfirmationFromRequest(requestPayload: payload);

      if (!mounted) {
        return;
      }

      setState(() {
        _confirmationPayload = result.confirmationPayload;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process request payload.')),
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
    final state = ref.watch(prototypeWalletProvider);
    final wallet = state.wallet;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Sender wallet: ${wallet.name}'),
            const SizedBox(height: 4),
            Text('Current balance: Rs. ${wallet.balance.toStringAsFixed(2)}'),
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
              child: Text(_isSubmitting ? 'Processing...' : 'Pay & Generate Confirmation QR'),
            ),
            const SizedBox(height: 16),
            if (_requestPayloadController.text.trim().isNotEmpty) ...[
              const Text('Parsed Request Preview'),
              const SizedBox(height: 8),
              _RequestPreview(payload: _requestPayloadController.text),
            ],
            const SizedBox(height: 16),
            if (_confirmationPayload != null) ...[
              const Text('Show this confirmation QR to Phone A (receiver):'),
              const SizedBox(height: 10),
              Center(
                child: QrImageView(
                  data: _confirmationPayload!,
                  size: 240,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(jsonDecode(_confirmationPayload!)),
                style: const TextStyle(fontSize: 12),
              ),
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
      final receiver = (parsed['receiverWalletName'] ?? parsed['receiverWalletId'] ?? '').toString();
      final amount = (parsed['amount'] ?? '').toString();
      return Text('Receiver: $receiver\nAmount: Rs. $amount');
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
