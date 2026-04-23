import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/auth_provider.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  final _amountController = TextEditingController(text: '200');
  String? _requestQrPayload;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Receiver: ${session?.name ?? 'Loading...'}'),
            const SizedBox(height: 6),
            SelectableText('Receiver User ID: ${session?.userId ?? 'not-ready'}'),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Request Amount'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (session == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Wallet session is not ready yet.')),
                  );
                  return;
                }

                final amount = double.tryParse(_amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount.')),
                  );
                  return;
                }

                final payload = jsonEncode({
                  'type': 'payment_request_v1',
                  'requestId': 'req_${DateTime.now().microsecondsSinceEpoch}',
                  'receiverUserId': session.userId,
                  'receiverName': session.name,
                  'amount': amount,
                  'timestamp': DateTime.now().toIso8601String(),
                });

                setState(() {
                  _requestQrPayload = payload;
                });
              },
              child: const Text('Generate Request QR'),
            ),
            const SizedBox(height: 16),
            if (_requestQrPayload != null) ...[
              const Text('Sender scans this request QR:'),
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
          ],
        ),
      ),
    );
  }
}
