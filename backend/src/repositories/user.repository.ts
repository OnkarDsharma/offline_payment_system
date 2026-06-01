import { pool } from '../db/pool';

export type CreateUserInput = {
  name: string;
  phone: string;
  passwordHash: string;
  publicKey?: string | null;
};

export type UserRow = {
  id: string;
  name: string;
  phone: string;
  passwordHash: string;
  publicKey: string | null;
};

type PublicUserRow = Omit<UserRow, 'passwordHash'>;

const mapUserRow = (row: Record<string, unknown>): UserRow => ({
  id: String(row.id),
  name: String(row.name),
  phone: String(row.phone),
  passwordHash: String(row.password_hash),
  publicKey: row.public_key ? String(row.public_key) : null,
});

const mapPublicUserRow = (row: Record<string, unknown>): PublicUserRow => ({
  id: String(row.id),
  name: String(row.name),
  phone: String(row.phone),
  publicKey: row.public_key ? String(row.public_key) : null,
});

export class UserRepository {
  async findByPhone(phone: string): Promise<UserRow | null> {
    const result = await pool.query(
      `
        SELECT id, name, phone, password_hash, public_key
        FROM users
        WHERE phone = $1
      `,
      [phone],
    );

    if (result.rowCount === 0) {
      return null;
    }

    return mapUserRow(result.rows[0]);
  }

  async findById(id: string): Promise<PublicUserRow | null> {
    const result = await pool.query(
      `
        SELECT id, name, phone, public_key
        FROM users
        WHERE id = $1
      `,
      [id],
    );

    if (result.rowCount === 0) {
      return null;
    }

    return mapPublicUserRow(result.rows[0]);
  }

  async updatePublicKey(params: { userId: string; publicKey: string }) {
    const result = await pool.query(
      `
        UPDATE users
        SET public_key = $2
        WHERE id = $1
        RETURNING id, name, phone, public_key
      `,
      [params.userId, params.publicKey],
    );

    if (result.rowCount === 0) {
      throw new Error('User not found');
    }

    return mapPublicUserRow(result.rows[0]);
  }

  async createWithWallet(input: CreateUserInput) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const userResult = await client.query(
        `
          INSERT INTO users (name, phone, password_hash, public_key)
          VALUES ($1, $2, $3, $4)
          RETURNING id, name, phone, public_key
        `,
        [input.name, input.phone, input.passwordHash, input.publicKey ?? null],
      );

      const user = mapPublicUserRow(userResult.rows[0]);

      await client.query(
        `
          INSERT INTO wallets (user_id)
          VALUES ($1)
        `,
        [user.id],
      );

      await client.query('COMMIT');

      return user;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
