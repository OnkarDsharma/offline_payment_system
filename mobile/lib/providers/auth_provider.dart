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
  await ref.read(keyManagerProvider).ensureKeyPair();

  final session = await db.getSession();
  ref.read(authSessionProvider.notifier).state = session;
});