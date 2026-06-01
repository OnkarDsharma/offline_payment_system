import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_mode_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/transactions_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';

class OfflineWalletApp extends ConsumerStatefulWidget {
  const OfflineWalletApp({super.key});

  @override
  ConsumerState<OfflineWalletApp> createState() => _OfflineWalletAppState();
}

class _OfflineWalletAppState extends ConsumerState<OfflineWalletApp>
    with WidgetsBindingObserver {
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _didInitialModeRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = ref
        .read(connectivityServiceProvider)
        .onConnectivityChanged
        .listen((result) {
      if (result != ConnectivityResult.none) {
        ref.read(appModeProvider.notifier).refreshMode();
        ref.read(syncServiceProvider).syncIfOnline();
      } else {
        ref.read(appModeProvider.notifier).refreshMode();
      }
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(appModeProvider.notifier).refreshMode();
      ref.read(syncServiceProvider).syncIfOnline();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appModeProvider.notifier).refreshMode();
      ref.read(syncServiceProvider).syncIfOnline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);

    return MaterialApp(
      title: 'Offline Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F8FC),
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Color(0xFF0F172A),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: const Color(0xFFD9E2EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: const Color(0xFF0F766E),
              width: 1.4,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        useMaterial3: true,
      ),
      home: bootstrap.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            Scaffold(body: Center(child: Text(error.toString()))),
        data: (_) {
          ref.watch(walletBootstrapProvider);
          ref.watch(transactionsBootstrapProvider);
          ref.watch(appModeProvider);
          if (!_didInitialModeRefresh) {
            _didInitialModeRefresh = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(appModeProvider.notifier).refreshMode();
              ref.read(syncServiceProvider).syncIfOnline();
            });
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
