import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/home_screen.dart';

class OfflineWalletApp extends ConsumerWidget {
  const OfflineWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: 'Offline Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006A6A)),
        useMaterial3: true,
      ),
      home: bootstrap.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(body: Center(child: Text(error.toString()))),
        data: (_) {
          ref.watch(walletBootstrapProvider);
          ref.watch(transactionsBootstrapProvider);
          return const HomeScreen();
        },
      ),
    );
  }
}