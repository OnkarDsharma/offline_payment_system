import 'package:dio/dio.dart';

import '../models/auth_session.dart';
import '../models/offline_token.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

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
    return SyncOfflineTokenSpentResponse(token: OfflineToken.fromApiMap(tokenMap));
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
    required String email,
    required String password,
    required String publicKey,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'publicKey': publicKey,
      },
    );

    return AuthSession.fromApiMap(response.data ?? const {});
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return AuthSession.fromApiMap(response.data ?? const {});
  }

  Future<Wallet> fetchWallet({required String token}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/wallet',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    return Wallet.fromApiMap(response.data ?? const {});
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

  Future<WalletTransaction> createTransfer({
    required String token,
    required String receiverUserId,
    required double amount,
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

  Future<List<WalletTransaction>> fetchTransactions({required String token}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/transactions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final items = (response.data?['transactions'] as List<dynamic>? ?? const []);
    return items
        .whereType<Map<String, dynamic>>()
        .map(WalletTransaction.fromApiMap)
        .toList();
  }
}
