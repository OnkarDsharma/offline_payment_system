import { readdir, readFile } from 'fs/promises';
import path from 'path';
import { pool } from '../db/pool';

const migrationsDirectory = path.resolve(__dirname, '../db/migrations');

const run = async () => {
  const files = (await readdir(migrationsDirectory))
    .filter((file) => file.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const migrationSql = await readFile(path.join(migrationsDirectory, file), 'utf8');
    console.log(`Running migration: ${file}`);
    await pool.query(migrationSql);
  }

  await pool.end();
  console.log('Migrations completed');
};

run().catch(async (error) => {
  console.error('Migration failed', error);
  await pool.end();
  process.exit(1);
});
