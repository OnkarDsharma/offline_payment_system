import { pool } from '../db/pool';

export type CreateUserInput = {
  name: string;
  email: string;
  passwordHash: string;
  publicKey: string;
};

export type UserRow = {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  publicKey: string;
};

type PublicUserRow = Omit<UserRow, 'passwordHash'>;

const mapUserRow = (row: Record<string, unknown>): UserRow => ({
  id: String(row.id),
  name: String(row.name),
  email: String(row.email),
  passwordHash: String(row.password_hash),
  publicKey: String(row.public_key),
});

const mapPublicUserRow = (row: Record<string, unknown>): PublicUserRow => ({
  id: String(row.id),
  name: String(row.name),
  email: String(row.email),
  publicKey: String(row.public_key),
});

export class UserRepository {
  async findByEmail(email: string): Promise<UserRow | null> {
    const result = await pool.query(
      `
        SELECT id, name, email, password_hash, public_key
        FROM users
        WHERE email = $1
      `,
      [email.toLowerCase()],
    );

    if (result.rowCount === 0) {
      return null;
    }

    return mapUserRow(result.rows[0]);
  }

  async findById(id: string): Promise<PublicUserRow | null> {
    const result = await pool.query(
      `
        SELECT id, name, email, public_key
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

  async createWithWallet(input: CreateUserInput) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const userResult = await client.query(
        `
          INSERT INTO users (name, email, password_hash, public_key)
          VALUES ($1, $2, $3, $4)
          RETURNING id, name, email, public_key
        `,
        [input.name, input.email.toLowerCase(), input.passwordHash, input.publicKey],
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
