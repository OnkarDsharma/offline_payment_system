import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/key_manager.dart';
import '../db/database_helper.dart';
import '../models/auth_session.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager();
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);
const _initialWalletBalancePaise = 500000;

bool _needsInitialWalletBackfill(Wallet wallet) {
  return wallet.onlineBalance == 0 &&
      wallet.offlineBalance == 0 &&
      wallet.lastSyncedAt == null;
}

AuthSession buildLocalFallbackSession(String publicKey) {
  final suffix = publicKey.hashCode.abs().toString().padLeft(6, '0');
  return AuthSession(
    userId: 'local_$suffix',
    name: 'Wallet ${suffix.substring(suffix.length - 4)}',
    phone: 'offline_$suffix',
    publicKey: publicKey,
    token: '',
  );
}

String buildDeviceId(String publicKey) {
  final suffix = publicKey.hashCode.abs().toString().padLeft(6, '0');
  return 'device_$suffix';
}

String buildWalletName(String publicKey) {
  final suffix = publicKey.hashCode.abs().toString().padLeft(6, '0');
  return 'Wallet ${suffix.substring(suffix.length - 4)}';
}

Future<AuthSession?> ensureServerBackedSession(Ref ref) async {
  final keyPair = await ref.read(keyManagerProvider).ensureKeyPair();
  final currentSession = ref.read(authSessionProvider);
  if (currentSession != null && currentSession.token.isNotEmpty) {
    return currentSession;
  }

  try {
    final demoSession = await ref.read(apiServiceProvider).createDemoSession(
          deviceId: buildDeviceId(keyPair.publicKey),
          name: buildWalletName(keyPair.publicKey),
          publicKey: keyPair.publicKey,
        );
    await ref.read(databaseHelperProvider).saveSession(demoSession);
    ref.read(authSessionProvider.notifier).state = demoSession;
    return demoSession;
  } catch (_) {
    return currentSession;
  }
}

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.read(databaseHelperProvider);
  await db.initialize();
  final keyPair = await ref.read(keyManagerProvider).ensureKeyPair();

  var session = await db.getSession();
  if (session == null) {
    final localFallbackSession = buildLocalFallbackSession(keyPair.publicKey);

    try {
      final demoSession = await ref.read(apiServiceProvider).createDemoSession(
            deviceId: buildDeviceId(keyPair.publicKey),
            name: buildWalletName(keyPair.publicKey),
            publicKey: keyPair.publicKey,
          );

      await db.saveSession(demoSession);
      session = demoSession;
    } catch (_) {
      await db.saveSession(localFallbackSession);
      session = localFallbackSession;
    }

    final existingWallet = await db.getWallet(session.userId);
    if (existingWallet == null || _needsInitialWalletBackfill(existingWallet)) {
      await db.saveWallet(
        Wallet(
          userId: session.userId,
          onlineBalance: _initialWalletBalancePaise,
          offlineBalance: _initialWalletBalancePaise,
          lastSyncedAt: null,
        ),
      );
    }
  } else if (session.token.isEmpty) {
    try {
      final demoSession = await ref.read(apiServiceProvider).createDemoSession(
            deviceId: buildDeviceId(keyPair.publicKey),
            name: buildWalletName(keyPair.publicKey),
            publicKey: keyPair.publicKey,
          );

      await db.saveSession(demoSession);
      session = demoSession;

      final existingWallet = await db.getWallet(session.userId);
      if (existingWallet == null || _needsInitialWalletBackfill(existingWallet)) {
        await db.saveWallet(
          Wallet(
            userId: session.userId,
            onlineBalance: _initialWalletBalancePaise,
            offlineBalance: _initialWalletBalancePaise,
            lastSyncedAt: null,
          ),
        );
      }
    } catch (_) {
      // Keep local fallback session if the backend is still unreachable.
    }
  } else {
    final existingWallet = await db.getWallet(session.userId);
    if (existingWallet != null && _needsInitialWalletBackfill(existingWallet)) {
      await db.saveWallet(
        existingWallet.copyWith(
          onlineBalance: _initialWalletBalancePaise,
          offlineBalance: _initialWalletBalancePaise,
        ),
      );
    }
  }

  ref.read(authSessionProvider.notifier).state = session;
});
