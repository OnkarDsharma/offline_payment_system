import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';

class PrototypeWallet {
  const PrototypeWallet({
    required this.id,
    required this.name,
    required this.balance,
  });

  final String id;
  final String name;
  final double balance;

  PrototypeWallet copyWith({double? balance}) {
    return PrototypeWallet(
      id: id,
      name: name,
      balance: balance ?? this.balance,
    );
  }
}

class PrototypeState {
  const PrototypeState({
    required this.wallet,
    required this.transactions,
    this.lastRequestQrPayload,
    this.lastConfirmationQrPayload,
  });

  final PrototypeWallet wallet;
  final List<WalletTransaction> transactions;
  final String? lastRequestQrPayload;
  final String? lastConfirmationQrPayload;

  PrototypeState copyWith({
    PrototypeWallet? wallet,
    List<WalletTransaction>? transactions,
    String? lastRequestQrPayload,
    String? lastConfirmationQrPayload,
  }) {
    return PrototypeState(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      lastRequestQrPayload: lastRequestQrPayload ?? this.lastRequestQrPayload,
      lastConfirmationQrPayload:
          lastConfirmationQrPayload ?? this.lastConfirmationQrPayload,
    );
  }
}

class OutgoingPaymentResult {
  const OutgoingPaymentResult({
    required this.message,
    this.confirmationPayload,
  });

  final String message;
  final String? confirmationPayload;
}

class PrototypeWalletController extends StateNotifier<PrototypeState> {
  PrototypeWalletController()
      : _storage = const FlutterSecureStorage(),
        super(
          const PrototypeState(
            wallet: PrototypeWallet(
              id: 'wallet_bootstrap',
              name: 'My Wallet',
              balance: 5000,
            ),
            transactions: [],
          ),
        ) {
    _initializeLocalWallet();
  }

  final FlutterSecureStorage _storage;

  static const _walletIdKey = 'prototype_wallet_id';
  static const _walletNameKey = 'prototype_wallet_name';
  static const _walletBalanceKey = 'prototype_wallet_balance';

  Future<void> _initializeLocalWallet() async {
    var walletId = await _storage.read(key: _walletIdKey);
    var walletName = await _storage.read(key: _walletNameKey);
    final savedBalance = await _storage.read(key: _walletBalanceKey);

    walletId ??= 'wallet_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    walletName ??= 'My Wallet';
    final balance = double.tryParse(savedBalance ?? '') ?? 5000;

    await _storage.write(key: _walletIdKey, value: walletId);
    await _storage.write(key: _walletNameKey, value: walletName);
    await _storage.write(key: _walletBalanceKey, value: balance.toStringAsFixed(2));

    state = state.copyWith(
      wallet: PrototypeWallet(id: walletId, name: walletName, balance: balance),
    );
  }

  Future<void> _persistWallet(PrototypeWallet wallet) async {
    await _storage.write(key: _walletIdKey, value: wallet.id);
    await _storage.write(key: _walletNameKey, value: wallet.name);
    await _storage.write(
      key: _walletBalanceKey,
      value: wallet.balance.toStringAsFixed(2),
    );
  }

  Future<void> updateWalletName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final updated = PrototypeWallet(
      id: state.wallet.id,
      name: trimmed,
      balance: state.wallet.balance,
    );
    state = state.copyWith(wallet: updated);
    await _persistWallet(updated);
  }

  String generatePaymentRequest({
    required double amount,
  }) {
    final payload = jsonEncode({
      'type': 'prototype_payment_request',
      'requestId': 'req_${DateTime.now().microsecondsSinceEpoch}',
      'receiverWalletId': state.wallet.id,
      'receiverWalletName': state.wallet.name,
      'amount': amount,
      'timestamp': DateTime.now().toIso8601String(),
    });

    state = state.copyWith(lastRequestQrPayload: payload);
    return payload;
  }

  Future<OutgoingPaymentResult> createOutgoingConfirmationFromRequest({
    required String requestPayload,
  }) async {
    try {
      final parsed = jsonDecode(requestPayload) as Map<String, dynamic>;
      final receiverWalletId = (parsed['receiverWalletId'] ?? '').toString();
      final receiverWalletName = (parsed['receiverWalletName'] ?? 'Receiver Wallet').toString();
      final amount = (parsed['amount'] as num?)?.toDouble() ?? 0;

      if (receiverWalletId.isEmpty || amount <= 0) {
        return const OutgoingPaymentResult(message: 'Invalid payment request QR payload.');
      }

      if (receiverWalletId == state.wallet.id) {
        return const OutgoingPaymentResult(message: 'Cannot pay your own wallet from the same device.');
      }

      if (state.wallet.balance < amount) {
        return OutgoingPaymentResult(
          message: 'Insufficient balance in ${state.wallet.name}.',
        );
      }

      final txId = 'tx_${DateTime.now().microsecondsSinceEpoch}';
      final updatedWallet = state.wallet.copyWith(balance: state.wallet.balance - amount);
      await _persistWallet(updatedWallet);

      final tx = WalletTransaction(
        id: txId,
        fromUserId: updatedWallet.id,
        toUserId: receiverWalletId,
        amount: amount,
        timestamp: DateTime.now(),
        status: TransactionStatus.completed,
        signature: null,
      );

      final confirmationPayload = jsonEncode({
        'type': 'prototype_payment_confirmation',
        'txId': txId,
        'senderWalletId': updatedWallet.id,
        'senderWalletName': updatedWallet.name,
        'receiverWalletId': receiverWalletId,
        'receiverWalletName': receiverWalletName,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
      });

      state = state.copyWith(
        wallet: updatedWallet,
        transactions: [tx, ...state.transactions],
        lastConfirmationQrPayload: confirmationPayload,
      );

      return OutgoingPaymentResult(
        message: 'Payment initiated. Show confirmation QR to receiver.',
        confirmationPayload: confirmationPayload,
      );
    } catch (_) {
      return const OutgoingPaymentResult(message: 'Failed to parse request QR payload.');
    }
  }

  Future<String> applyIncomingConfirmation({required String confirmationPayload}) async {
    try {
      final parsed = jsonDecode(confirmationPayload) as Map<String, dynamic>;
      final txId = (parsed['txId'] ?? '').toString();
      final senderWalletId = (parsed['senderWalletId'] ?? '').toString();
      final senderWalletName = (parsed['senderWalletName'] ?? 'Sender Wallet').toString();
      final receiverWalletId = (parsed['receiverWalletId'] ?? '').toString();
      final amount = (parsed['amount'] as num?)?.toDouble() ?? 0;

      if (txId.isEmpty || senderWalletId.isEmpty || receiverWalletId.isEmpty || amount <= 0) {
        return 'Invalid payment confirmation QR payload.';
      }

      if (receiverWalletId != state.wallet.id) {
        return 'This confirmation QR is not for this wallet.';
      }

      final exists = state.transactions.any((tx) => tx.id == txId);
      if (exists) {
        return 'This confirmation is already applied.';
      }

      final updatedWallet = state.wallet.copyWith(balance: state.wallet.balance + amount);
      await _persistWallet(updatedWallet);

      final tx = WalletTransaction(
        id: txId,
        fromUserId: senderWalletId,
        toUserId: updatedWallet.id,
        amount: amount,
        timestamp: DateTime.now(),
        status: TransactionStatus.completed,
        signature: null,
      );

      state = state.copyWith(
        wallet: updatedWallet,
        transactions: [tx, ...state.transactions],
      );

      return 'Received Rs. ${amount.toStringAsFixed(2)} from $senderWalletName.';
    } catch (_) {
      return 'Failed to parse confirmation QR payload.';
    }
  }
}

final prototypeWalletProvider =
    StateNotifierProvider<PrototypeWalletController, PrototypeState>((ref) {
  return PrototypeWalletController();
});
