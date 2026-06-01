import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/auth_session.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_wallet.db');
    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion != newVersion) {
          await db.execute('DROP TABLE IF EXISTS auth_session');
          await db.execute('DROP TABLE IF EXISTS wallet');
          await db.execute('DROP TABLE IF EXISTS wallet_cache');
          await db.execute('DROP TABLE IF EXISTS transactions');
          await db.execute('DROP TABLE IF EXISTS offline_transactions');
          await _createSchema(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        public_key TEXT NOT NULL,
        token TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE wallet (
        user_id TEXT PRIMARY KEY,
        online_balance INTEGER NOT NULL,
        offline_balance INTEGER NOT NULL,
        last_synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE offline_transactions (
        transaction_id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        currency TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        from_public_key TEXT NOT NULL,
        signature TEXT NOT NULL,
        direction TEXT NOT NULL,
        status TEXT NOT NULL,
        rejection_reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> saveSession(AuthSession session) async {
    final db = await database;
    await db.insert(
      'auth_session',
      session.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AuthSession?> getSession() async {
    final db = await database;
    final rows =
        await db.query('auth_session', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) {
      return null;
    }
    return AuthSession.fromDbMap(rows.first);
  }

  Future<void> clearSession() async {
    final db = await database;
    await db.delete('auth_session', where: 'id = ?', whereArgs: [1]);
  }

  Future<void> saveWallet(Wallet wallet) async {
    final db = await database;
    await db.insert(
      'wallet',
      wallet.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Wallet?> getWallet(String userId) async {
    final db = await database;
    final rows =
        await db.query('wallet', where: 'user_id = ?', whereArgs: [userId]);
    if (rows.isEmpty) {
      return null;
    }
    return Wallet.fromDbMap(rows.first);
  }

  Future<void> updateWalletBalances({
    required String userId,
    int? onlineBalance,
    int? offlineBalance,
    String? lastSyncedAt,
  }) async {
    final db = await database;
    final existing = await getWallet(userId);
    final wallet = (existing ??
            Wallet(
              userId: userId,
              onlineBalance: 500000,
              offlineBalance: 500000,
              lastSyncedAt: null,
            ))
        .copyWith(
      onlineBalance: onlineBalance,
      offlineBalance: offlineBalance,
      lastSyncedAt: lastSyncedAt,
    );
    await saveWallet(wallet);
  }

  Future<void> clearWallet() async {
    final db = await database;
    await db.delete('wallet');
  }

  Future<void> upsertOfflineTransaction(WalletTransaction transaction) async {
    final db = await database;
    await db.insert(
      'offline_transactions',
      transaction.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WalletTransaction>> getTransactions() async {
    final db = await database;
    final rows =
        await db.query('offline_transactions', orderBy: 'timestamp DESC');
    return rows.map(WalletTransaction.fromDbMap).toList();
  }

  Future<List<WalletTransaction>> getPendingTransactions() async {
    final db = await database;
    final rows = await db.query(
      'offline_transactions',
      where: 'status = ?',
      whereArgs: ['PENDING_SYNC'],
      orderBy: 'timestamp ASC',
    );
    return rows.map(WalletTransaction.fromDbMap).toList();
  }

  Future<WalletTransaction?> getTransactionById(String transactionId) async {
    final db = await database;
    final rows = await db.query(
      'offline_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WalletTransaction.fromDbMap(rows.first);
  }

  Future<void> updateTransactionSyncResult({
    required String transactionId,
    required OfflineTransactionStatus status,
    String? rejectionReason,
  }) async {
    final db = await database;
    await db.update(
      'offline_transactions',
      {
        'status': switch (status) {
          OfflineTransactionStatus.pendingSync => 'PENDING_SYNC',
          OfflineTransactionStatus.confirmed => 'CONFIRMED',
          OfflineTransactionStatus.rejected => 'REJECTED',
        },
        'rejection_reason': rejectionReason,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> clearTransactions() async {
    final db = await database;
    await db.delete('offline_transactions');
  }
}
