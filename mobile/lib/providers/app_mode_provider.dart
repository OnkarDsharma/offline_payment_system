import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';
import 'transactions_provider.dart';
import 'wallet_provider.dart';

enum AppMode {
  checking,
  online,
  offline,
  syncing,
}

final appModeProvider =
    StateNotifierProvider<AppModeController, AppMode>((ref) {
  return AppModeController(ref);
});

class AppModeController extends StateNotifier<AppMode> {
  AppModeController(this._ref) : super(AppMode.checking);

  final Ref _ref;

  Future<void> refreshMode() async {
    if (state != AppMode.syncing) {
      state = AppMode.checking;
    }

    final backendReachable =
        await _ref.read(apiServiceProvider).isBackendReachable();
    if (!backendReachable) {
      state = AppMode.offline;
      return;
    }

    final session = await ensureServerBackedSession(_ref);
    if (session == null || session.token.isEmpty) {
      state = AppMode.offline;
      return;
    }

    try {
      final remoteWallet = await _ref.read(apiServiceProvider).fetchWallet(
            token: session.token,
            userId: session.userId,
          );
      await _ref.read(databaseHelperProvider).saveWallet(remoteWallet);
      _ref.read(walletProvider.notifier).state = remoteWallet;

      final remoteTransactions =
          await _ref.read(apiServiceProvider).fetchTransactions(
                token: session.token,
              );
      for (final transaction in remoteTransactions) {
        await _ref.read(databaseHelperProvider).upsertOfflineTransaction(
              transaction,
            );
      }
      _ref.read(transactionsProvider.notifier).state = remoteTransactions;

      state = AppMode.online;
    } catch (_) {
      final localSession = _ref.read(authSessionProvider);
      if (localSession != null && localSession.token.isNotEmpty) {
        state = AppMode.online;
      } else {
        state = AppMode.offline;
      }
    }
  }

  Future<Map<String, int>?> syncNow() async {
    state = AppMode.syncing;
    try {
      final result = await _ref.read(syncServiceProvider).syncIfOnline(reportErrors: true);
      await refreshMode();
      return result;
    } catch (_) {
      await refreshMode();
      rethrow;
    }
  }

  bool get isOnline => state == AppMode.online;
  bool get isOffline => state == AppMode.offline;
}
