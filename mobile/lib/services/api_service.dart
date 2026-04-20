import 'package:dio/dio.dart';

import '../models/auth_session.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

class ApiService {
  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://10.0.2.2:4000/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  final Dio _dio;

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