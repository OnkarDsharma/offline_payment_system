import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import 'auth_provider.dart';

final transactionsProvider =
    StateProvider<List<WalletTransaction>>((ref) => const []);

final transactionsBootstrapProvider =
    FutureProvider<List<WalletTransaction>>((ref) async {
  final db = ref.read(databaseHelperProvider);
  final cached = await db.getTransactions();
  ref.read(transactionsProvider.notifier).state = cached;

  final session = ref.read(authSessionProvider);
  if (session == null) {
    return cached;
  }

  try {
    final remoteTransactions =
        await ref.read(apiServiceProvider).fetchTransactions(
              token: session.token,
            );
    for (final transaction in remoteTransactions) {
      await db.upsertOfflineTransaction(transaction);
    }
    ref.read(transactionsProvider.notifier).state = remoteTransactions;
  } catch (_) {
    // Keep cached transactions when backend fetch fails.
  }

  return ref.read(transactionsProvider);
});
