import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/key_manager.dart';
import '../db/database_helper.dart';
import '../models/auth_session.dart';
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

final appBootstrapProvider = FutureProvider<void>((ref) async {
  final db = ref.read(databaseHelperProvider);
  await db.initialize();
  final keyPair = await ref.read(keyManagerProvider).ensureKeyPair();

  var session = await db.getSession();
  if (session == null) {
    final suffix = keyPair.publicKey.hashCode.abs().toString().padLeft(6, '0');
    final deviceId = 'device_$suffix';
    final name = 'Wallet ${suffix.substring(suffix.length - 4)}';

    final demoSession = await ref.read(apiServiceProvider).createDemoSession(
          deviceId: deviceId,
          name: name,
          publicKey: keyPair.publicKey,
        );

    await db.saveSession(demoSession);
    session = demoSession;
  }

  ref.read(authSessionProvider.notifier).state = session;
});