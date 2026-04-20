import { pool } from '../db/pool';

export type WalletRow = {
  onlineBalance: number;
  offlineBalance: number;
};

export class WalletRepository {
  async findByUserId(userId: string): Promise<WalletRow | null> {
    const result = await pool.query(
      `
        SELECT online_balance, offline_balance
        FROM wallets
        WHERE user_id = $1
      `,
      [userId],
    );

    if (result.rowCount === 0) {
      return null;
    }

    return {
      onlineBalance: Number(result.rows[0].online_balance),
      offlineBalance: Number(result.rows[0].offline_balance),
    };
  }
}
