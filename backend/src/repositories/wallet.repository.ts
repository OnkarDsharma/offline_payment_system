import { pool } from '../db/pool';
import { PoolClient } from 'pg';
import { WalletBalances, OfflineTokenRecord } from '../models/types';
import { env } from '../config/env';
import { createHmac } from 'crypto';

const mapWalletRow = (row: Record<string, unknown>): WalletBalances => ({
  userId: String(row.user_id),
  onlineBalance: Number(row.online_balance),
  offlineBalance: Number(row.offline_balance),
});

export class WalletRepository {
  async findByUserId(userId: string): Promise<WalletBalances | null> {
    const result = await pool.query(
      `
        SELECT user_id, online_balance, offline_balance
        FROM wallets
        WHERE user_id = $1
      `,
      [userId],
    );

    if (result.rowCount === 0) {
      return null;
    }

    return mapWalletRow(result.rows[0]);
  }

  private base64Url(input: Buffer) {
    return input.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  private signTokenPayload(id: string, ownerUserId: string, amount: number, issuedAt: string) {
    const hmac = createHmac('sha256', env.JWT_SECRET);
    hmac.update([id, ownerUserId, amount.toString(), issuedAt].join('|'));
    return this.base64Url(hmac.digest());
  }

  async mintOfflineToken(userId: string, amount: number): Promise<{ wallet: WalletBalances; token: OfflineTokenRecord }> {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');
      await client.query(`SELECT user_id FROM wallets WHERE user_id = $1 FOR UPDATE`, [userId]);

      const wRes = await client.query(
        `SELECT user_id, online_balance, offline_balance FROM wallets WHERE user_id = $1 FOR UPDATE`,
        [userId],
      );
      if (wRes.rowCount === 0) throw new Error('Wallet not found');
      const onlineBalance = Number(wRes.rows[0].online_balance);
      if (onlineBalance < amount) throw new Error('Insufficient online balance');

      await client.query(`UPDATE wallets SET online_balance = online_balance - $2, offline_balance = offline_balance + $2, updated_at = NOW() WHERE user_id = $1`, [userId, amount]);

      const insertRes = await client.query(
        `INSERT INTO offline_tokens (id, owner_user_id, amount, status, signature, issued_at) VALUES (gen_random_uuid(), $1, $2, 'ISSUED', $3, NOW()) RETURNING *`,
        [userId, amount, ''],
      );

      // compute signature using returned id and issued_at
      const tokenRow = insertRes.rows[0];
      const id = String(tokenRow.id);
      const issuedAt = tokenRow.issued_at.toISOString();
      const signature = this.signTokenPayload(id, userId, amount, issuedAt);

      await client.query(`UPDATE offline_tokens SET signature = $2 WHERE id = $1`, [id, signature]);

      const updatedWalletRes = await client.query(`SELECT user_id, online_balance, offline_balance FROM wallets WHERE user_id = $1`, [userId]);

      await client.query('COMMIT');

      const wallet: WalletBalances = {
        userId: String(updatedWalletRes.rows[0].user_id),
        onlineBalance: Number(updatedWalletRes.rows[0].online_balance),
        offlineBalance: Number(updatedWalletRes.rows[0].offline_balance),
      };

      const token: OfflineTokenRecord = {
        id,
        ownerUserId: userId,
        amount: Number(amount),
        status: 'ISSUED',
        signature,
        issuedAt,
        spentAt: null,
        redeemedAt: null,
      };

      return { wallet, token };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async listOfflineTokens(userId: string, status?: string): Promise<OfflineTokenRecord[]> {
    const params: any[] = [userId];
    let q = `SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at FROM offline_tokens WHERE owner_user_id = $1`;
    if (status) {
      params.push(status);
      q += ` AND status = $2`;
    }
    q += ` ORDER BY issued_at DESC`;

    const res = await pool.query(q, params);
    return res.rows.map((row) => ({
      id: String(row.id),
      ownerUserId: String(row.owner_user_id),
      amount: Number(row.amount),
      status: String(row.status) as OfflineTokenRecord['status'],
      signature: String(row.signature),
      issuedAt: row.issued_at ? new Date(String(row.issued_at)).toISOString() : '',
      spentAt: row.spent_at ? new Date(String(row.spent_at)).toISOString() : null,
      redeemedAt: row.redeemed_at ? new Date(String(row.redeemed_at)).toISOString() : null,
    }));
  }

  async syncOfflineTokenSpent(userId: string, tokenId: string): Promise<OfflineTokenRecord> {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const tokenRes = await client.query(`SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at FROM offline_tokens WHERE id = $1 FOR UPDATE`, [tokenId]);
      if (tokenRes.rowCount === 0) throw new Error('Token not found');
      const token = tokenRes.rows[0];
      if (String(token.owner_user_id) !== userId) throw new Error('Not token owner');
      if (String(token.status) !== 'ISSUED') throw new Error('Token not in ISSUED state');

      await client.query(`UPDATE offline_tokens SET status = 'SPENT', spent_at = NOW() WHERE id = $1`, [tokenId]);

      const updated = await client.query(`SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at FROM offline_tokens WHERE id = $1`, [tokenId]);
      await client.query('COMMIT');

      const row = updated.rows[0];
      return {
        id: String(row.id),
        ownerUserId: String(row.owner_user_id),
        amount: Number(row.amount),
        status: String(row.status) as OfflineTokenRecord['status'],
        signature: String(row.signature),
        issuedAt: row.issued_at ? new Date(String(row.issued_at)).toISOString() : '',
        spentAt: row.spent_at ? new Date(String(row.spent_at)).toISOString() : null,
        redeemedAt: row.redeemed_at ? new Date(String(row.redeemed_at)).toISOString() : null,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async redeemOfflineToken(currentUserId: string, tokenPayload: { id: string; ownerUserId: string; amount: number; signature: string; issuedAt: string; }) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const tokenRes = await client.query(`SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at FROM offline_tokens WHERE id = $1 FOR UPDATE`, [tokenPayload.id]);
      if (tokenRes.rowCount === 0) throw new Error('Token not found');
      const tokenRow = tokenRes.rows[0];
      if (String(tokenRow.owner_user_id) !== tokenPayload.ownerUserId) throw new Error('Owner mismatch');
      if (String(tokenRow.signature) !== tokenPayload.signature) throw new Error('Invalid signature');
      if (String(tokenRow.status) === 'REDEEMED' || String(tokenRow.status) === 'REVOKED') throw new Error('Token cannot be redeemed');

      // lock wallets
      await this.lockWallets(client, [tokenPayload.ownerUserId, currentUserId]);

      const ownerWallet = await this.getWalletForUpdate(client, tokenPayload.ownerUserId);
      if (!ownerWallet || ownerWallet.offlineBalance < tokenPayload.amount) throw new Error('Insufficient offline balance for owner');

      await client.query(`UPDATE wallets SET offline_balance = offline_balance - $2, updated_at = NOW() WHERE user_id = $1`, [tokenPayload.ownerUserId, tokenPayload.amount]);
      await client.query(`UPDATE wallets SET online_balance = online_balance + $2, updated_at = NOW() WHERE user_id = $1`, [currentUserId, tokenPayload.amount]);

      await client.query(`UPDATE offline_tokens SET status = 'REDEEMED', redeemed_at = NOW() WHERE id = $1`, [tokenPayload.id]);

      const txInsert = await client.query(
        `INSERT INTO transactions (id, from_user_id, to_user_id, amount, currency, type, status) VALUES (gen_random_uuid(), $1, $2, $3, 'INR', 'OFFLINE', 'CONFIRMED') RETURNING *`,
        [tokenPayload.ownerUserId, currentUserId, tokenPayload.amount],
      );

      const updatedWalletRes = await client.query(`SELECT user_id, online_balance, offline_balance FROM wallets WHERE user_id = $1`, [currentUserId]);

      await client.query('COMMIT');

      const wallet: WalletBalances = {
        userId: String(updatedWalletRes.rows[0].user_id),
        onlineBalance: Number(updatedWalletRes.rows[0].online_balance),
        offlineBalance: Number(updatedWalletRes.rows[0].offline_balance),
      };

      const updatedToken = await pool.query(`SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at FROM offline_tokens WHERE id = $1`, [tokenPayload.id]);
      const row = updatedToken.rows[0];

      return {
        wallet,
        token: {
          id: String(row.id),
          ownerUserId: String(row.owner_user_id),
          amount: Number(row.amount),
          status: String(row.status) as OfflineTokenRecord['status'],
          signature: String(row.signature),
          issuedAt: row.issued_at ? new Date(String(row.issued_at)).toISOString() : '',
          spentAt: row.spent_at ? new Date(String(row.spent_at)).toISOString() : null,
          redeemedAt: row.redeemed_at ? new Date(String(row.redeemed_at)).toISOString() : null,
        },
        transaction: txInsert.rows[0],
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async lockWallets(client: PoolClient, userIds: string[]) {
    const uniqueOrderedUserIds = [...new Set(userIds)].sort();
    for (const userId of uniqueOrderedUserIds) {
      await client.query(`SELECT user_id FROM wallets WHERE user_id = $1 FOR UPDATE`, [userId]);
    }
  }

  private async getWalletForUpdate(client: PoolClient, userId: string) {
    const result = await client.query(`SELECT user_id, online_balance, offline_balance FROM wallets WHERE user_id = $1 FOR UPDATE`, [userId]);
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
