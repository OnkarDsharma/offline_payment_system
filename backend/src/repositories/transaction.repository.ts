import { PoolClient } from 'pg';
import { pool } from '../db/pool';
import { SyncResult } from '../models/types';

export type OfflineSyncTransactionInput = {
  transactionId: string;
  fromUserId: string;
  toUserId: string;
  amount: number;
  currency: string;
  timestamp: string;
  fromPublicKey: string;
  signature: string;
};

export type TransactionRecord = {
  transactionId: string;
  fromUserId: string;
  toUserId: string;
  amount: number;
  currency: string;
  timestamp: string;
  fromPublicKey: string;
  signature: string;
  direction: 'SENT' | 'RECEIVED';
  status: 'CONFIRMED' | 'REJECTED';
  rejectionReason: string | null;
  createdAt: string;
};

const canonicalString = (transaction: OfflineSyncTransactionInput) =>
  [
    transaction.transactionId,
    transaction.fromUserId,
    transaction.toUserId,
    transaction.amount.toString(),
    transaction.currency,
    transaction.timestamp,
  ].join('|');

const mapTransactionRow = (row: Record<string, unknown>, currentUserId: string): TransactionRecord => ({
  transactionId: String(row.id),
  fromUserId: String(row.from_user_id),
  toUserId: String(row.to_user_id),
  amount: Number(row.amount),
  currency: String(row.currency),
  timestamp: row.device_timestamp ? new Date(String(row.device_timestamp)).toISOString() : '',
  fromPublicKey: row.from_public_key ? String(row.from_public_key) : '',
  signature: row.signature ? String(row.signature) : '',
  direction: String(row.from_user_id) === currentUserId ? 'SENT' : 'RECEIVED',
  status: String(row.status) as 'CONFIRMED' | 'REJECTED',
  rejectionReason: row.rejection_reason ? String(row.rejection_reason) : null,
  createdAt: new Date(String(row.created_at)).toISOString(),
});

const decodeBase64Url = (value: string) => new Uint8Array(Buffer.from(value, 'base64url'));

let nobleEd25519ModulePromise: Promise<typeof import('@noble/ed25519')> | null = null;

const getEd25519Module = async () => {
  nobleEd25519ModulePromise ??= import('@noble/ed25519');
  return nobleEd25519ModulePromise;
};

export class TransactionRepository {
  async findByUserId(userId: string): Promise<TransactionRecord[]> {
    const result = await pool.query(
      `
        SELECT
          id,
          from_user_id,
          to_user_id,
          amount,
          currency,
          from_public_key,
          signature,
          device_timestamp,
          status,
          rejection_reason,
          created_at
        FROM transactions
        WHERE from_user_id = $1 OR to_user_id = $1
        ORDER BY created_at DESC
      `,
      [userId],
    );

    return result.rows.map((row) => mapTransactionRow(row, userId));
  }

  async createOnlineTransfer(params: {
    senderUserId: string;
    receiverUserId: string;
    amount: number;
  }): Promise<TransactionRecord> {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');
      await this.lockWallets(client, [params.senderUserId, params.receiverUserId]);

      const senderWallet = await this.getWalletForUpdate(client, params.senderUserId);
      if (!senderWallet) {
        throw new Error('Sender wallet not found');
      }
      if (senderWallet.onlineBalance < params.amount) {
        throw new Error('Insufficient online balance');
      }

      await client.query(
        `UPDATE wallets SET online_balance = online_balance - $2, updated_at = NOW() WHERE user_id = $1`,
        [params.senderUserId, params.amount],
      );
      await client.query(
        `UPDATE wallets SET online_balance = online_balance + $2, updated_at = NOW() WHERE user_id = $1`,
        [params.receiverUserId, params.amount],
      );

      const insertResult = await client.query(
        `
          INSERT INTO transactions (
            id,
            from_user_id,
            to_user_id,
            amount,
            currency,
            type,
            status
          )
          VALUES (gen_random_uuid(), $1, $2, $3, 'INR', 'ONLINE', 'CONFIRMED')
          RETURNING *
        `,
        [params.senderUserId, params.receiverUserId, params.amount],
      );

      await client.query('COMMIT');
      return mapTransactionRow(insertResult.rows[0], params.senderUserId);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async syncOfflineTransactions(params: {
    currentUserId: string;
    transactions: OfflineSyncTransactionInput[];
  }): Promise<{ results: SyncResult[]; updatedBalances: { onlineBalance: number; offlineBalance: number } }> {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const results: SyncResult[] = [];
      const orderedTransactions = [...params.transactions].sort((left, right) =>
        left.timestamp.localeCompare(right.timestamp),
      );

      for (const transaction of orderedTransactions) {
        if (params.currentUserId !== transaction.fromUserId && params.currentUserId !== transaction.toUserId) {
          throw new Error('Authenticated user is not part of one or more synced transactions');
        }

        const existing = await client.query(
          `SELECT id, status, rejection_reason FROM transactions WHERE id = $1`,
          [transaction.transactionId],
        );
        if ((existing.rowCount ?? 0) > 0) {
          results.push({
            transactionId: transaction.transactionId,
            status: String(existing.rows[0].status) as 'CONFIRMED' | 'REJECTED',
            rejectionReason: existing.rows[0].rejection_reason
              ? (String(existing.rows[0].rejection_reason) as SyncResult['rejectionReason'])
              : null,
          });
          continue;
        }

        const sender = await client.query(`SELECT id, public_key FROM users WHERE id = $1`, [
          transaction.fromUserId,
        ]);
        if (sender.rowCount === 0 || String(sender.rows[0].public_key ?? '') !== transaction.fromPublicKey) {
          await this.insertRejectedTransaction(client, transaction, 'KEY_MISMATCH');
          results.push({
            transactionId: transaction.transactionId,
            status: 'REJECTED',
            rejectionReason: 'KEY_MISMATCH',
          });
          continue;
        }

        const { verify } = await getEd25519Module();
        const isValidSignature = await verify(
          decodeBase64Url(transaction.signature),
          Buffer.from(canonicalString(transaction), 'utf8'),
          decodeBase64Url(transaction.fromPublicKey),
        );
        if (!isValidSignature) {
          await this.insertRejectedTransaction(client, transaction, 'INVALID_SIGNATURE');
          results.push({
            transactionId: transaction.transactionId,
            status: 'REJECTED',
            rejectionReason: 'INVALID_SIGNATURE',
          });
          continue;
        }

        const timestamp = new Date(transaction.timestamp);
        if (Number.isNaN(timestamp.getTime()) || Date.now() - timestamp.getTime() > 7 * 24 * 60 * 60 * 1000) {
          await this.insertRejectedTransaction(client, transaction, 'EXPIRED');
          results.push({
            transactionId: transaction.transactionId,
            status: 'REJECTED',
            rejectionReason: 'EXPIRED',
          });
          continue;
        }

        await this.lockWallets(client, [transaction.fromUserId, transaction.toUserId]);
        const senderWallet = await this.getWalletForUpdate(client, transaction.fromUserId);
        if (!senderWallet || senderWallet.offlineBalance < transaction.amount) {
          await this.insertRejectedTransaction(client, transaction, 'INSUFFICIENT_FUNDS');
          results.push({
            transactionId: transaction.transactionId,
            status: 'REJECTED',
            rejectionReason: 'INSUFFICIENT_FUNDS',
          });
          continue;
        }

        await client.query(
          `UPDATE wallets SET offline_balance = offline_balance - $2, updated_at = NOW() WHERE user_id = $1`,
          [transaction.fromUserId, transaction.amount],
        );
        await client.query(
          `UPDATE wallets SET online_balance = online_balance + $2, updated_at = NOW() WHERE user_id = $1`,
          [transaction.toUserId, transaction.amount],
        );

        await client.query(
          `
            INSERT INTO transactions (
              id,
              from_user_id,
              to_user_id,
              amount,
              currency,
              type,
              status,
              rejection_reason,
              from_public_key,
              signature,
              device_timestamp
            )
            VALUES ($1, $2, $3, $4, $5, 'OFFLINE', 'CONFIRMED', NULL, $6, $7, $8)
          `,
          [
            transaction.transactionId,
            transaction.fromUserId,
            transaction.toUserId,
            transaction.amount,
            transaction.currency,
            transaction.fromPublicKey,
            transaction.signature,
            transaction.timestamp,
          ],
        );

        results.push({
          transactionId: transaction.transactionId,
          status: 'CONFIRMED',
          rejectionReason: null,
        });
      }

      const walletResult = await client.query(
        `SELECT online_balance, offline_balance FROM wallets WHERE user_id = $1`,
        [params.currentUserId],
      );

      await client.query('COMMIT');

      return {
        results,
        updatedBalances: {
          onlineBalance: Number(walletResult.rows[0].online_balance),
          offlineBalance: Number(walletResult.rows[0].offline_balance),
        },
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async insertRejectedTransaction(
    client: PoolClient,
    transaction: OfflineSyncTransactionInput,
    rejectionReason: SyncResult['rejectionReason'],
  ) {
    await client.query(
      `
        INSERT INTO transactions (
          id,
          from_user_id,
          to_user_id,
          amount,
          currency,
          type,
          status,
          rejection_reason,
          from_public_key,
          signature,
          device_timestamp
        )
        VALUES ($1, $2, $3, $4, $5, 'OFFLINE', 'REJECTED', $6, $7, $8, $9)
      `,
      [
        transaction.transactionId,
        transaction.fromUserId,
        transaction.toUserId,
        transaction.amount,
        transaction.currency,
        rejectionReason,
        transaction.fromPublicKey,
        transaction.signature,
        transaction.timestamp,
      ],
    );
  }

  private async lockWallets(client: PoolClient, userIds: string[]) {
    const uniqueOrderedUserIds = [...new Set(userIds)].sort();
    for (const userId of uniqueOrderedUserIds) {
      await client.query(
        `SELECT user_id FROM wallets WHERE user_id = $1 FOR UPDATE`,
        [userId],
      );
    }
  }

  private async getWalletForUpdate(client: PoolClient, userId: string) {
    const result = await client.query(
      `SELECT user_id, online_balance, offline_balance FROM wallets WHERE user_id = $1 FOR UPDATE`,
      [userId],
    );
    if (result.rowCount === 0) {
      return null;
    }
    return {
      userId: String(result.rows[0].user_id),
      onlineBalance: Number(result.rows[0].online_balance),
      offlineBalance: Number(result.rows[0].offline_balance),
    };
  }
}
