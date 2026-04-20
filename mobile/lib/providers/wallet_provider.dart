import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import 'auth_provider.dart';

final walletProvider = StateProvider<Wallet>((ref) {
  return const Wallet(onlineBalance: 5000, offlineBalance: 1000);
});

final walletBootstrapProvider = FutureProvider<Wallet>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final cachedWallet = await db.getWallet();
  if (cachedWallet != null) {
    ref.read(walletProvider.notifier).state = cachedWallet;
  }

  final session = ref.read(authSessionProvider);
  if (session == null) {
    return ref.read(walletProvider);
  }

  try {
    final remoteWallet = await ref.read(apiServiceProvider).fetchWallet(token: session.token);
    await db.saveWallet(remoteWallet);
    ref.read(walletProvider.notifier).state = remoteWallet;
  } catch (_) {
    // Keep cached wallet when backend fetch fails.
  }

  return ref.read(walletProvider);
});