import 'package:dio/dio.dart';

import '../models/auth_session.dart';
import '../models/offline_token.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

class SyncResult {
  const SyncResult({
    required this.transactionId,
    required this.status,
    this.rejectionReason,
  });

  final String transactionId;
  final String status;
  final String? rejectionReason;

  factory SyncResult.fromApiMap(Map<String, dynamic> map) {
    return SyncResult(
      transactionId: (map['transaction_id'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      rejectionReason: map['rejection_reason']?.toString(),
    );
  }
}

class SyncTransactionsResponse {
  const SyncTransactionsResponse({
    required this.results,
    required this.updatedBalances,
  });

  final List<SyncResult> results;
  final Wallet updatedBalances;

  factory SyncTransactionsResponse.fromApiMap(Map<String, dynamic> map) {
    final results = (map['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SyncResult.fromApiMap)
        .toList();

    return SyncTransactionsResponse(
      results: results,
      updatedBalances: Wallet.fromApiMap(
        (map['updated_balances'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }
}

class MintOfflineTokensResponse {
  const MintOfflineTokensResponse({
    required this.wallet,
    required this.tokenIds,
  });

  final Wallet wallet;
  final List<String> tokenIds;

  factory MintOfflineTokensResponse.fromApiMap(Map<String, dynamic> map) {
    final walletMap = (map['wallet'] as Map<String, dynamic>? ?? const {});
    final tokens = (map['tokens'] as List<dynamic>? ?? const []);

    return MintOfflineTokensResponse(
      wallet: Wallet.fromApiMap(walletMap),
      tokenIds: tokens
          .whereType<Map<String, dynamic>>()
          .map((token) => (token['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList(),
    );
  }
}

class SyncOfflineTokenSpentResponse {
  const SyncOfflineTokenSpentResponse({required this.token});

  final OfflineToken token;

  factory SyncOfflineTokenSpentResponse.fromApiMap(Map<String, dynamic> map) {
    final tokenMap = (map['token'] as Map<String, dynamic>? ?? const {});
    return SyncOfflineTokenSpentResponse(
      token: OfflineToken.fromApiMap(tokenMap),
    );
  }
}

class RedeemOfflineTokenResponse {
  const RedeemOfflineTokenResponse({
    required this.wallet,
    required this.token,
    required this.transactionId,
    required this.transactionStatus,
  });

  final Wallet wallet;
  final OfflineToken token;
  final String transactionId;
  final String transactionStatus;

  factory RedeemOfflineTokenResponse.fromApiMap(Map<String, dynamic> map) {
    final walletMap = (map['wallet'] as Map<String, dynamic>? ?? const {});
    final tokenMap = (map['token'] as Map<String, dynamic>? ?? const {});
    final txMap = (map['transaction'] as Map<String, dynamic>? ?? const {});

    return RedeemOfflineTokenResponse(
      wallet: Wallet.fromApiMap(walletMap),
      token: OfflineToken.fromApiMap(tokenMap),
      transactionId: (txMap['id'] ?? '').toString(),
      transactionStatus: (txMap['status'] ?? '').toString(),
    );
  }
}

class ApiService {
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:4000/api',
            ),
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  final Dio _dio;

  Future<bool> isBackendReachable() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/health',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AuthSession> createDemoSession({
    required String deviceId,
    required String name,
    required String publicKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/demo-session',
      data: {
        'deviceId': deviceId,
        'name': name,
        'publicKey': publicKey,
      },
    );

    return AuthSession.fromApiMap(response.data ?? const {});
  }

  Future<AuthSession> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'phone': phone,
        'password': password,
      },
    );

    return AuthSession.fromApiMap(response.data ?? const {});
  }

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'phone': phone,
        'password': password,
      },
    );

    return AuthSession.fromApiMap(response.data ?? const {});
  }

  Future<void> registerKey({
    required String token,
    required String publicKey,
  }) async {
    await _dio.post<void>(
      '/auth/register-key',
      data: {'public_key': publicKey},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
  }

  Future<Wallet> fetchWallet({
    required String token,
    required String userId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/wallet/balance',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    return Wallet.fromApiMap({
      'user_id': userId,
      ...(response.data ?? const {}),
    });
  }

  Future<MintOfflineTokensResponse> mintOfflineTokens({
    required String token,
    required double amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallet/mint-offline-tokens',
      data: {
        'amount': amount,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return MintOfflineTokensResponse.fromApiMap(response.data ?? const {});
  }

  Future<List<OfflineToken>> fetchOfflineTokens({
    required String token,
    String? status,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/wallet/offline-tokens',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final items = (response.data?['tokens'] as List<dynamic>? ?? const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(OfflineToken.fromApiMap)
        .toList();
  }

  Future<SyncOfflineTokenSpentResponse> syncOfflineTokenSpent({
    required String token,
    required String tokenId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallet/sync-offline-token-spent',
      data: {
        'tokenId': tokenId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return SyncOfflineTokenSpentResponse.fromApiMap(response.data ?? const {});
  }

  Future<RedeemOfflineTokenResponse> redeemOfflineToken({
    required String token,
    required OfflineToken offlineToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallet/redeem-offline-token',
      data: {
        'token': offlineToken.toRedeemPayloadMap(),
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return RedeemOfflineTokenResponse.fromApiMap(response.data ?? const {});
  }

  Future<SyncTransactionsResponse> syncTransactions({
    required String token,
    required List<WalletTransaction> transactions,
    required String userId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/sync',
      data: {
        'transactions':
            transactions.map((transaction) => transaction.toJson()).toList(),
      },
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    return SyncTransactionsResponse.fromApiMap({
      ...?response.data,
      'updated_balances': {
        'user_id': userId,
        ...((response.data?['updated_balances'] as Map<String, dynamic>?) ??
            const {}),
      },
    });
  }

  Future<List<WalletTransaction>> fetchTransactions({
    required String token,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/transactions',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    final items =
        (response.data?['transactions'] as List<dynamic>? ?? const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(WalletTransaction.fromApiMap)
        .toList();
  }

  Future<WalletTransaction> createTransfer({
    required String token,
    required String receiverUserId,
    required int amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/transactions',
      data: {
        'receiverUserId': receiverUserId,
        'amount': amount,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return WalletTransaction.fromApiMap(response.data ?? const {});
  }
}
