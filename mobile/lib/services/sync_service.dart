import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../providers/wallet_provider.dart';
import 'connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref);
});

class SyncService {
  SyncService(this._ref);

  final Ref _ref;
  /// Attempts to sync pending offline transactions with the server.
  /// Returns a summary map: {'synced': n, 'rejected': m} when work was done,
  /// or null if there was nothing to do.
  Future<Map<String, int>?> syncIfOnline({bool reportErrors = false}) async {
    final session = _ref.read(authSessionProvider);
    if (session == null || session.token.isEmpty) {
      return null;
    }

    final isOnline = await _ref.read(connectivityServiceProvider).isOnline();
    if (!isOnline) {
      return null;
    }

    final db = _ref.read(databaseHelperProvider);
    try {
      final pendingTransactions = await db.getPendingTransactions();
      if (pendingTransactions.isEmpty) {
        final remoteWallet = await _ref.read(apiServiceProvider).fetchWallet(
              token: session.token,
              userId: session.userId,
            );
        await db.saveWallet(remoteWallet);
        _ref.read(walletProvider.notifier).state = remoteWallet;
        return null;
      }

      final response = await _ref.read(apiServiceProvider).syncTransactions(
            token: session.token,
            transactions: pendingTransactions,
            userId: session.userId,
          );

      int synced = 0;
      int rejected = 0;

      for (final result in response.results) {
        final existing = await db.getTransactionById(result.transactionId);
        final status = switch (result.status.toUpperCase()) {
          'CONFIRMED' => OfflineTransactionStatus.confirmed,
          'REJECTED' => OfflineTransactionStatus.rejected,
          _ => OfflineTransactionStatus.pendingSync,
        };

        await db.updateTransactionSyncResult(
          transactionId: result.transactionId,
          status: status,
          rejectionReason: result.rejectionReason,
        );

        if (status == OfflineTransactionStatus.confirmed) {
          synced += 1;
        } else if (status == OfflineTransactionStatus.rejected) {
          rejected += 1;
        }

        if (existing != null &&
            status == OfflineTransactionStatus.rejected &&
            existing.direction == OfflineTransactionDirection.sent) {
          final wallet = await db.getWallet(session.userId);
          if (wallet != null) {
            await db.updateWalletBalances(
              userId: session.userId,
              offlineBalance: wallet.offlineBalance + existing.amount,
            );
          }
        }
      }

      final refreshedWallet = response.updatedBalances.copyWith(
        lastSyncedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await db.saveWallet(refreshedWallet);
      _ref.read(walletProvider.notifier).state = refreshedWallet;
      _ref.read(transactionsProvider.notifier).state = await db.getTransactions();
      return {'synced': synced, 'rejected': rejected};
    } catch (e) {
      if (reportErrors) rethrow;
      // Stay silent during opportunistic sync; local state remains usable offline.
      return null;
    }
  }
}
