CREATE TABLE IF NOT EXISTS offline_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL CHECK (status IN ('ISSUED', 'SPENT', 'REDEEMED', 'REVOKED')),
  signature TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  spent_at TIMESTAMPTZ,
  redeemed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_offline_tokens_owner_user_id
  ON offline_tokens(owner_user_id);

CREATE INDEX IF NOT EXISTS idx_offline_tokens_status
  ON offline_tokens(status);
