import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../models/wallet.dart';
import 'auth_provider.dart';
import 'transactions_provider.dart';
import 'wallet_provider.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = _ref.read(databaseHelperProvider);
      final session = await _ref.read(apiServiceProvider).register(
            name: name,
            phone: phone,
            password: password,
          );
      final keyPair = await _ref.read(keyManagerProvider).ensureKeyPair();
      await _ref.read(apiServiceProvider).registerKey(
            token: session.token,
            publicKey: keyPair.publicKey,
          );
      final hydratedSession = AuthSession(
        userId: session.userId,
        name: session.name,
        phone: session.phone,
        publicKey: keyPair.publicKey,
        token: session.token,
      );

      await db.saveSession(hydratedSession);
      _ref.read(authSessionProvider.notifier).state = hydratedSession;

      _ref.invalidate(walletBootstrapProvider);
      _ref.invalidate(transactionsBootstrapProvider);
    });
  }

  Future<void> login({
    required String phone,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final db = _ref.read(databaseHelperProvider);
      final session = await _ref.read(apiServiceProvider).login(
            phone: phone,
            password: password,
          );
      final keyPair = await _ref.read(keyManagerProvider).ensureKeyPair();
      await _ref.read(apiServiceProvider).registerKey(
            token: session.token,
            publicKey: keyPair.publicKey,
          );
      final hydratedSession = AuthSession(
        userId: session.userId,
        name: session.name,
        phone: session.phone,
        publicKey: keyPair.publicKey,
        token: session.token,
      );

      await db.saveSession(hydratedSession);
      _ref.read(authSessionProvider.notifier).state = hydratedSession;

      _ref.invalidate(walletBootstrapProvider);
      _ref.invalidate(transactionsBootstrapProvider);
    });
  }

  Future<void> logout() async {
    final db = _ref.read(databaseHelperProvider);
    await db.clearSession();
    await db.clearWallet();
    await db.clearTransactions();

    _ref.read(authSessionProvider.notifier).state = null;
    _ref.read(walletProvider.notifier).state = const Wallet(
      userId: '',
      onlineBalance: 500000,
      offlineBalance: 500000,
    );
    _ref.read(transactionsProvider.notifier).state = const [];

    _ref.invalidate(walletBootstrapProvider);
    _ref.invalidate(transactionsBootstrapProvider);
    state = const AsyncData(null);
  }
}
