import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/offline_token.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';

class OfflineTokensScreen extends ConsumerStatefulWidget {
  const OfflineTokensScreen({super.key});

  @override
  ConsumerState<OfflineTokensScreen> createState() => _OfflineTokensScreenState();
}

class _OfflineTokensScreenState extends ConsumerState<OfflineTokensScreen> {
  final _mintAmountController = TextEditingController(text: '100');
  final _redeemPayloadController = TextEditingController();

  bool _loadingTokens = false;
  bool _minting = false;
  bool _redeeming = false;
  List<OfflineToken> _tokens = const [];
  String? _transferPayload;

  @override
  void initState() {
    super.initState();
    _refreshTokens();
  }

  @override
  void dispose() {
    _mintAmountController.dispose();
    _redeemPayloadController.dispose();
    super.dispose();
  }

  Future<void> _refreshTokens() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      return;
    }

    setState(() {
      _loadingTokens = true;
    });

    try {
      final tokens = await ref.read(apiServiceProvider).fetchOfflineTokens(
            token: session.token,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _tokens = tokens;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load offline tokens: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingTokens = false;
        });
      }
    }
  }

  Future<void> _mintToken() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet session is not ready yet.')),
      );
      return;
    }

    final amount = double.tryParse(_mintAmountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid mint amount.')),
      );
      return;
    }

    setState(() {
      _minting = true;
    });

    try {
      final result = await ref.read(apiServiceProvider).mintOfflineTokens(
            token: session.token,
            amount: amount,
          );

      ref.read(walletProvider.notifier).state = result.wallet;
      ref.invalidate(walletBootstrapProvider);
      await ref.read(walletBootstrapProvider.future);
      await _refreshTokens();

      if (!mounted) {
        return;
      }

      final tokenIds = result.tokenIds.isEmpty ? 'none' : result.tokenIds.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minted tokens: $tokenIds')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mint failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _minting = false;
        });
      }
    }
  }

  void _generateTransferPayload(OfflineToken token) {
    final payload = jsonEncode({
      'type': 'offline_token_v1',
      'token': token.toRedeemPayloadMap(),
    });

    setState(() {
      _transferPayload = payload;
      _redeemPayloadController.text = payload;
    });
  }

  Future<void> _syncTokenSpent(OfflineToken token) async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      return;
    }

    try {
      await ref.read(apiServiceProvider).syncOfflineTokenSpent(
            token: session.token,
            tokenId: token.id,
          );
      await _refreshTokens();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token synced as SPENT.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sync spent token: $error')),
      );
    }
  }

  Future<void> _redeemPayload() async {
    final session = ref.read(authSessionProvider);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet session is not ready yet.')),
      );
      return;
    }

    final payloadText = _redeemPayloadController.text.trim();
    if (payloadText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste or scan an offline token payload.')),
      );
      return;
    }

    setState(() {
      _redeeming = true;
    });

    try {
      final decoded = jsonDecode(payloadText) as Map<String, dynamic>;
      final tokenMap = decoded['token'] as Map<String, dynamic>?;
      if (tokenMap == null) {
        throw const FormatException('Invalid offline token payload.');
      }

      final offlineToken = OfflineToken.fromApiMap(tokenMap);
      final result = await ref.read(apiServiceProvider).redeemOfflineToken(
            token: session.token,
            offlineToken: offlineToken,
          );

      ref.read(walletProvider.notifier).state = result.wallet;
      ref.invalidate(walletBootstrapProvider);
      ref.invalidate(transactionsBootstrapProvider);
      await ref.read(walletBootstrapProvider.future);
      await ref.read(transactionsBootstrapProvider.future);
      await _refreshTokens();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Token redeemed. Transaction: ${result.transactionId} (${result.transactionStatus})',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redeem failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _redeeming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Tokens')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('User: ${session?.name ?? 'Loading...'}'),
          const SizedBox(height: 6),
          SelectableText('User ID: ${session?.userId ?? 'not-ready'}'),
          const SizedBox(height: 14),
          TextField(
            controller: _mintAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Mint amount'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _minting ? null : _mintToken,
            icon: const Icon(Icons.offline_bolt),
            label: Text(_minting ? 'Minting...' : 'Mint Offline Token'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadingTokens ? null : _refreshTokens,
            icon: const Icon(Icons.refresh),
            label: Text(_loadingTokens ? 'Refreshing...' : 'Refresh Tokens'),
          ),
          const SizedBox(height: 14),
          Text(
            'My Offline Tokens',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_tokens.isEmpty)
            const Text('No tokens yet. Mint one to begin offline flow.')
          else
            ..._tokens.map(
              (token) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Token: ${token.id.substring(0, 8)}...'),
                      const SizedBox(height: 4),
                      Text('Amount: Rs. ${token.amount.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      Text('Status: ${token.status}'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => _generateTransferPayload(token),
                              child: const Text('Generate Transfer QR'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: token.status == 'ISSUED'
                                  ? () => _syncTokenSpent(token)
                                  : null,
                              child: const Text('Sync SPENT'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_transferPayload != null) ...[
            const Text('Transfer this token payload to receiver:'),
            const SizedBox(height: 8),
            Center(
              child: QrImageView(
                data: _transferPayload!,
                size: 220,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(jsonDecode(_transferPayload!)),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(),
          const SizedBox(height: 10),
          const Text('Redeem/Synchronize received token'),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () async {
              final payload = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const _TokenScannerScreen(title: 'Scan Offline Token QR'),
                ),
              );

              if (payload != null) {
                _redeemPayloadController.text = payload;
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Token QR'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _redeemPayloadController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Token payload to redeem',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _redeeming ? null : _redeemPayload,
            child: Text(_redeeming ? 'Redeeming...' : 'Redeem Token to Sync'),
          ),
        ],
      ),
    );
  }
}

class _TokenScannerScreen extends StatefulWidget {
  const _TokenScannerScreen({required this.title});

  final String title;

  @override
  State<_TokenScannerScreen> createState() => _TokenScannerScreenState();
}

class _TokenScannerScreenState extends State<_TokenScannerScreen> {
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
