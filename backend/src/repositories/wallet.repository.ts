import { pool } from '../db/pool';
import { createHmac, timingSafeEqual } from 'crypto';
import { env } from '../config/env';
import {
  MintOfflineTokensResult,
  OfflineTokenRecord,
  OfflineTokenStatus,
  RedeemOfflineTokenPayload,
  RedeemOfflineTokenResult,
  SyncOfflineTokenSpentResult,
} from '../models/types';

export type WalletRow = {
  onlineBalance: number;
  offlineBalance: number;
};

const mapWalletRow = (row: Record<string, unknown>): WalletRow => ({
  onlineBalance: Number(row.online_balance),
  offlineBalance: Number(row.offline_balance),
});

const mapOfflineTokenRow = (row: Record<string, unknown>): OfflineTokenRecord => ({
  id: String(row.id),
  ownerUserId: String(row.owner_user_id),
  amount: Number(row.amount),
  status: String(row.status) as OfflineTokenStatus,
  signature: String(row.signature),
  issuedAt: String(row.issued_at),
  spentAt: row.spent_at ? String(row.spent_at) : null,
  redeemedAt: row.redeemed_at ? String(row.redeemed_at) : null,
});

const buildSignaturePayload = (token: {
  id: string;
  ownerUserId: string;
  amount: number;
  issuedAt: string;
}) => {
  return [token.id, token.ownerUserId, token.amount.toFixed(2), token.issuedAt].join(':');
};

const createTokenSignature = (token: {
  id: string;
  ownerUserId: string;
  amount: number;
  issuedAt: string;
}) => {
  return createHmac('sha256', env.JWT_SECRET)
    .update(buildSignaturePayload(token))
    .digest('hex');
};

const signaturesMatch = (left: string, right: string) => {
  const leftBuffer = Buffer.from(left, 'hex');
  const rightBuffer = Buffer.from(right, 'hex');

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return timingSafeEqual(leftBuffer, rightBuffer);
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

    return mapWalletRow(result.rows[0]);
  }

  async mintOfflineTokens(params: {
    userId: string;
    amount: number;
  }): Promise<MintOfflineTokensResult> {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const walletResult = await client.query(
        `
          SELECT online_balance, offline_balance
          FROM wallets
          WHERE user_id = $1
          FOR UPDATE
        `,
        [params.userId],
      );

      if (walletResult.rowCount === 0) {
        throw new Error('Wallet not found');
      }

      const wallet = mapWalletRow(walletResult.rows[0]);
      if (wallet.onlineBalance < params.amount) {
        throw new Error('Insufficient online balance to mint offline tokens');
      }

      const updatedWalletResult = await client.query(
        `
          UPDATE wallets
          SET
            online_balance = online_balance - $2,
            offline_balance = offline_balance + $2,
            updated_at = NOW()
          WHERE user_id = $1
          RETURNING online_balance, offline_balance
        `,
        [params.userId, params.amount],
      );

      const tokenInsertResult = await client.query(
        `
          INSERT INTO offline_tokens (owner_user_id, amount, status, signature)
          VALUES ($1, $2, 'ISSUED', 'PENDING_SIGNATURE')
          RETURNING id, amount, status, signature, issued_at
        `,
        [params.userId, params.amount],
      );

      const insertedToken = tokenInsertResult.rows[0] as Record<string, unknown>;
      const signature = createTokenSignature({
        id: String(insertedToken.id),
        ownerUserId: params.userId,
        amount: Number(insertedToken.amount),
        issuedAt: String(insertedToken.issued_at),
      });

      const tokenUpdateResult = await client.query(
        `
          UPDATE offline_tokens
          SET signature = $2
          WHERE id = $1
          RETURNING id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at
        `,
        [insertedToken.id, signature],
      );

      await client.query('COMMIT');

      return {
        wallet: mapWalletRow(updatedWalletResult.rows[0]),
        tokens: tokenUpdateResult.rows.map((row) => mapOfflineTokenRow(row)),
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async listOfflineTokens(params: {
    userId: string;
    status?: OfflineTokenStatus;
  }): Promise<OfflineTokenRecord[]> {
    const result = params.status
      ? await pool.query(
          `
            SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at
            FROM offline_tokens
            WHERE owner_user_id = $1 AND status = $2
            ORDER BY issued_at DESC
          `,
          [params.userId, params.status],
        )
      : await pool.query(
          `
            SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at
            FROM offline_tokens
            WHERE owner_user_id = $1
            ORDER BY issued_at DESC
          `,
          [params.userId],
        );

    return result.rows.map((row) => mapOfflineTokenRow(row));
  }

  async syncOfflineTokenSpent(params: {
    userId: string;
    tokenId: string;
  }): Promise<SyncOfflineTokenSpentResult> {
    const result = await pool.query(
      `
        UPDATE offline_tokens
        SET status = 'SPENT', spent_at = NOW()
        WHERE id = $1 AND owner_user_id = $2 AND status = 'ISSUED'
        RETURNING id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at
      `,
      [params.tokenId, params.userId],
    );

    if (result.rowCount === 0) {
      throw new Error('Token is not available for spent sync');
    }

    return {
      token: mapOfflineTokenRow(result.rows[0]),
    };
  }

  async redeemOfflineToken(params: {
    receiverUserId: string;
    token: RedeemOfflineTokenPayload;
  }): Promise<RedeemOfflineTokenResult> {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const tokenResult = await client.query(
        `
          SELECT id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at
          FROM offline_tokens
          WHERE id = $1
          FOR UPDATE
        `,
        [params.token.id],
      );

      if (tokenResult.rowCount === 0) {
        throw new Error('Offline token not found');
      }

      const dbToken = mapOfflineTokenRow(tokenResult.rows[0]);
      if (dbToken.ownerUserId !== params.token.ownerUserId) {
        throw new Error('Token owner mismatch');
      }

      if (dbToken.amount !== params.token.amount) {
        throw new Error('Token amount mismatch');
      }

      if (dbToken.issuedAt !== params.token.issuedAt) {
        throw new Error('Token issuedAt mismatch');
      }

      if (dbToken.ownerUserId === params.receiverUserId) {
        throw new Error('Cannot redeem your own offline token');
      }

      const expectedSignature = createTokenSignature({
        id: dbToken.id,
        ownerUserId: dbToken.ownerUserId,
        amount: dbToken.amount,
        issuedAt: dbToken.issuedAt,
      });

      const dbSignatureValid = signaturesMatch(dbToken.signature, expectedSignature);
      const payloadSignatureValid = signaturesMatch(params.token.signature, expectedSignature);
      if (!dbSignatureValid || !payloadSignatureValid) {
        throw new Error('Offline token signature verification failed');
      }

      if (dbToken.status === 'REDEEMED') {
        throw new Error('Offline token already redeemed');
      }

      if (dbToken.status === 'REVOKED') {
        throw new Error('Offline token revoked');
      }

      if (dbToken.status !== 'ISSUED' && dbToken.status !== 'SPENT') {
        throw new Error('Offline token cannot be redeemed from its current status');
      }

      const receiverWalletResult = await client.query(
        `
          UPDATE wallets
          SET online_balance = online_balance + $2, updated_at = NOW()
          WHERE user_id = $1
          RETURNING online_balance, offline_balance
        `,
        [params.receiverUserId, dbToken.amount],
      );

      if (receiverWalletResult.rowCount === 0) {
        throw new Error('Receiver wallet not found');
      }

      const redeemResult = await client.query(
        `
          UPDATE offline_tokens
          SET status = 'REDEEMED', redeemed_at = NOW()
          WHERE id = $1
          RETURNING id, owner_user_id, amount, status, signature, issued_at, spent_at, redeemed_at
        `,
        [dbToken.id],
      );

      const transactionResult = await client.query(
        `
          INSERT INTO transactions (
            sender_user_id,
            receiver_user_id,
            amount,
            status,
            signature,
            server_timestamp
          )
          VALUES ($1, $2, $3, 'CONFIRMED', $4, NOW())
          RETURNING id, status
        `,
        [dbToken.ownerUserId, params.receiverUserId, dbToken.amount, dbToken.signature],
      );

      await client.query('COMMIT');

      return {
        wallet: mapWalletRow(receiverWalletResult.rows[0]),
        token: mapOfflineTokenRow(redeemResult.rows[0]),
        transaction: {
          id: String(transactionResult.rows[0].id),
          status: String(transactionResult.rows[0].status),
        },
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
