export type WalletBalances = {
  userId: string;
  onlineBalance: number;
  offlineBalance: number;
};

export type UserRecord = {
  id: string;
  name: string;
  phone: string;
  publicKey: string | null;
};

export type SyncRejectionReason =
  | 'INSUFFICIENT_FUNDS'
  | 'INVALID_SIGNATURE'
  | 'DUPLICATE'
  | 'EXPIRED'
  | 'KEY_MISMATCH';

export type SyncResult = {
  transactionId: string;
  status: 'CONFIRMED' | 'REJECTED';
  rejectionReason: SyncRejectionReason | null;
};

export type OfflineTokenRecord = {
  id: string;
  ownerUserId: string;
  amount: number;
  status: 'ISSUED' | 'SPENT' | 'REDEEMED' | 'REVOKED';
  signature: string;
  issuedAt: string;
  spentAt: string | null;
  redeemedAt: string | null;
};
