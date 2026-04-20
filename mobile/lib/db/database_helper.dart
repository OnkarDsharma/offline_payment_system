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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE auth_session (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            public_key TEXT NOT NULL,
            token TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE wallet_cache (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            online_balance REAL NOT NULL,
            offline_balance REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            from_user_id TEXT NOT NULL,
            to_user_id TEXT NOT NULL,
            amount REAL NOT NULL,
            timestamp TEXT NOT NULL,
            status TEXT NOT NULL,
            signature TEXT
          )
        ''');
      },
    );

    return _database!;
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
    final rows = await db.query('auth_session', where: 'id = ?', whereArgs: [1]);
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
      'wallet_cache',
      wallet.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Wallet?> getWallet() async {
    final db = await database;
    final rows = await db.query('wallet_cache', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) {
      return null;
    }
    return Wallet.fromDbMap(rows.first);
  }

  Future<void> clearWallet() async {
    final db = await database;
    await db.delete('wallet_cache', where: 'id = ?', whereArgs: [1]);
  }

  Future<void> replaceTransactions(List<WalletTransaction> transactions) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      for (final transaction in transactions) {
        await txn.insert(
          'transactions',
          transaction.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<WalletTransaction>> getTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'timestamp DESC');
    return rows.map(WalletTransaction.fromDbMap).toList();
  }

  Future<void> clearTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }
}