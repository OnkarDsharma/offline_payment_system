export type WalletBalances = {
  onlineBalance: number;
  offlineBalance: number;
};

export type OfflineTokenStatus = 'ISSUED' | 'SPENT' | 'REDEEMED' | 'REVOKED';

export type OfflineTokenRecord = {
  id: string;
  ownerUserId: string;
  amount: number;
  status: OfflineTokenStatus;
  signature: string;
  issuedAt: string;
  spentAt?: string | null;
  redeemedAt?: string | null;
};

export type RedeemOfflineTokenPayload = {
  id: string;
  ownerUserId: string;
  amount: number;
  signature: string;
  issuedAt: string;
};

export type MintOfflineTokensResult = {
  wallet: WalletBalances;
  tokens: OfflineTokenRecord[];
};

export type SyncOfflineTokenSpentResult = {
  token: OfflineTokenRecord;
};

export type RedeemOfflineTokenResult = {
  wallet: WalletBalances;
  token: OfflineTokenRecord;
  transaction: {
    id: string;
    status: string;
  };
};

export type UserRecord = {
  id: string;
  name: string;
  email: string;
  publicKey: string;
};

export type TransactionStatus =
  | 'PENDING_SYNC'
  | 'CONFIRMED'
  | 'REJECTED'
  | 'COMPLETED'
  | 'FAILED';
