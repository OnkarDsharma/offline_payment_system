CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  public_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wallets (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  online_balance NUMERIC(14, 2) NOT NULL DEFAULT 5000.00,
  offline_balance NUMERIC(14, 2) NOT NULL DEFAULT 1000.00,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  receiver_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL CHECK (
    status IN ('PENDING_SYNC', 'CONFIRMED', 'REJECTED', 'COMPLETED', 'FAILED')
  ),
  signature TEXT,
  device_timestamp TIMESTAMPTZ,
  server_timestamp TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_sender_user_id
  ON transactions(sender_user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_receiver_user_id
  ON transactions(receiver_user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_status
  ON transactions(status);
