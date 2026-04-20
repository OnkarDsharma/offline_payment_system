import { PoolClient } from 'pg';
import { pool } from '../db/pool';

export type TransactionRecord = {
  id: string;
  senderUserId: string;
  receiverUserId: string;
  amount: number;
  status: string;
  createdAt: string;
};

const mapTransactionRow = (row: Record<string, unknown>): TransactionRecord => ({
  id: String(row.id),
  senderUserId: String(row.sender_user_id),
  receiverUserId: String(row.receiver_user_id),
  amount: Number(row.amount),
  status: String(row.status),
  createdAt: String(row.created_at),
});

export class TransactionRepository {
  async findByUserId(userId: string): Promise<TransactionRecord[]> {
    const result = await pool.query(
      `
        SELECT id, sender_user_id, receiver_user_id, amount, status, created_at
        FROM transactions
        WHERE sender_user_id = $1 OR receiver_user_id = $1
        ORDER BY created_at DESC
      `,
      [userId],
    );

    return result.rows.map((row) => mapTransactionRow(row));
  }

  async createTransfer(params: {
    senderUserId: string;
    receiverUserId: string;
    amount: number;
  }): Promise<TransactionRecord> {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const lockedWallets = await this.lockWallets(client, [
        params.senderUserId,
        params.receiverUserId,
      ]);
      const senderWallet = lockedWallets.get(params.senderUserId) ?? null;
      const receiverWallet = lockedWallets.get(params.receiverUserId) ?? null;

      if (!senderWallet) {
        throw new Error('Sender wallet not found');
      }

      if (!receiverWallet) {
        throw new Error('Receiver wallet not found');
      }

      if (senderWallet.onlineBalance < params.amount) {
        throw new Error('Insufficient online balance');
      }

      await client.query(
        `
          UPDATE wallets
          SET online_balance = online_balance - $2, updated_at = NOW()
          WHERE user_id = $1
        `,
        [params.senderUserId, params.amount],
      );

      await client.query(
        `
          UPDATE wallets
          SET online_balance = online_balance + $2, updated_at = NOW()
          WHERE user_id = $1
        `,
        [params.receiverUserId, params.amount],
      );

      const insertResult = await client.query(
        `
          INSERT INTO transactions (
            sender_user_id,
            receiver_user_id,
            amount,
            status,
            server_timestamp
          )
          VALUES ($1, $2, $3, 'COMPLETED', NOW())
          RETURNING id, sender_user_id, receiver_user_id, amount, status, created_at
        `,
        [params.senderUserId, params.receiverUserId, params.amount],
      );

      await client.query('COMMIT');

      return mapTransactionRow(insertResult.rows[0]);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async lockWallets(client: PoolClient, userIds: string[]) {
    const uniqueOrderedUserIds = [...new Set(userIds)].sort();
    const result = new Map<
      string,
      { userId: string; onlineBalance: number; offlineBalance: number }
    >();

    for (const userId of uniqueOrderedUserIds) {
      const wallet = await this.lockWallet(client, userId);
      if (wallet) {
        result.set(userId, wallet);
      }
    }

    return result;
  }

  private async lockWallet(client: PoolClient, userId: string) {
    const result = await client.query(
      `
        SELECT user_id, online_balance, offline_balance
        FROM wallets
        WHERE user_id = $1
        FOR UPDATE
      `,
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
