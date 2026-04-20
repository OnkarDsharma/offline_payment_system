# Backend Local Run

## 1. Configure environment

Copy `.env.example` to `.env` and update the values for your local PostgreSQL instance.

Current local `.env` values in this workspace:

```env
PORT=4000
NODE_ENV=development
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/offline_wallet
JWT_SECRET=local-dev-secret
```

If your local PostgreSQL password is not `postgres`, update the password part of `DATABASE_URL`.

## Database setup needed from your side

You already have PostgreSQL 17 installed and the Windows service is running. To make the backend work for real, you need:

1. A PostgreSQL user you know the password for.
2. A database named `offline_wallet`.
3. The correct connection string in `backend/.env`.

If you want to use the default `postgres` superuser, run these commands in `psql` after logging in with your real password:

```sql
CREATE DATABASE offline_wallet;
```

If you prefer a dedicated app user, run:

```sql
CREATE USER offline_wallet_app WITH PASSWORD 'choose-a-strong-password';
CREATE DATABASE offline_wallet OWNER offline_wallet_app;
GRANT ALL PRIVILEGES ON DATABASE offline_wallet TO offline_wallet_app;
```

Then set:

```env
DATABASE_URL=postgresql://offline_wallet_app:choose-a-strong-password@localhost:5432/offline_wallet
```

## 2. Run migrations

```bash
cmd /c npm run migrate
```

## 3. Start the API

```bash
cmd /c npm run dev
```

## 4. Test with a REST client

Use [rest-client/stage1.http](/D:/sem%204%20minor/backend/rest-client/stage1.http) in the VS Code REST Client extension, or recreate the same requests in Thunder Client.

The Stage 1 flow is:

1. Register Alice
2. Register Bob
3. Login both users
4. Fetch wallet balance
5. Create a transaction
6. Fetch wallet balances again to verify debit and credit

## What I verified already

- Backend dependencies are installed.
- TypeScript type-check passes with `cmd /c npm run lint`.
- PostgreSQL 17 is installed locally.
- The PostgreSQL Windows service is running.

## What is still blocked

The current `backend/.env` assumes the password for user `postgres` is `postgres`, but your local PostgreSQL rejected that password. Once you either:

1. tell me the correct username/password to place in `DATABASE_URL`, or
2. update `backend/.env` yourself,

I can run migrations, start the backend, and walk through the REST tests end to end.
