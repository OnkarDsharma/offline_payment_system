import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import 'auth_provider.dart';

const _initialWalletBalancePaise = 500000;

bool _needsInitialWalletBackfill(Wallet wallet) {
  return wallet.onlineBalance == 0 &&
      wallet.offlineBalance == 0 &&
      wallet.lastSyncedAt == null;
}

final walletProvider = StateProvider<Wallet>((ref) {
  return const Wallet(
    userId: '',
    onlineBalance: _initialWalletBalancePaise,
    offlineBalance: _initialWalletBalancePaise,
  );
});

final walletBootstrapProvider = FutureProvider<Wallet>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final session = ref.read(authSessionProvider);
  if (session == null) {
    return ref.read(walletProvider);
  }

  final cachedWallet = await db.getWallet(session.userId);
  if (cachedWallet != null) {
    final walletToUse = _needsInitialWalletBackfill(cachedWallet)
        ? cachedWallet.copyWith(
            onlineBalance: _initialWalletBalancePaise,
            offlineBalance: _initialWalletBalancePaise,
          )
        : cachedWallet;
    if (_needsInitialWalletBackfill(cachedWallet)) {
      await db.saveWallet(walletToUse);
    }
    ref.read(walletProvider.notifier).state = walletToUse;
  }

  try {
    final remoteWallet = await ref.read(apiServiceProvider).fetchWallet(
          token: session.token,
          userId: session.userId,
        );
    await db.saveWallet(remoteWallet);
    ref.read(walletProvider.notifier).state = remoteWallet;
  } catch (_) {
    // Keep cached wallet when backend fetch fails.
  }

  return ref.read(walletProvider);
});
