export type WalletBalances = {
  onlineBalance: number;
  offlineBalance: number;
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
