import {
  MintOfflineTokensResult,
  OfflineTokenStatus,
  RedeemOfflineTokenPayload,
  RedeemOfflineTokenResult,
  SyncOfflineTokenSpentResult,
  WalletBalances,
} from '../models/types';
import { WalletRepository } from '../repositories/wallet.repository';

export class WalletService {
  private readonly walletRepository = new WalletRepository();

  async getWallet(userId: string): Promise<WalletBalances> {
    const wallet = await this.walletRepository.findByUserId(userId);

    if (!wallet) {
      throw new Error('Wallet not found');
    }

    return wallet;
  }

  async mintOfflineTokens(params: {
    userId: string;
    amount: number;
  }): Promise<MintOfflineTokensResult> {
    if (!Number.isFinite(params.amount) || params.amount <= 0) {
      throw new Error('Amount must be greater than zero');
    }

    return this.walletRepository.mintOfflineTokens(params);
  }

  async listOfflineTokens(params: {
    userId: string;
    status?: OfflineTokenStatus;
  }) {
    return this.walletRepository.listOfflineTokens(params);
  }

  async syncOfflineTokenSpent(params: {
    userId: string;
    tokenId: string;
  }): Promise<SyncOfflineTokenSpentResult> {
    return this.walletRepository.syncOfflineTokenSpent(params);
  }

  async redeemOfflineToken(params: {
    receiverUserId: string;
    token: RedeemOfflineTokenPayload;
  }): Promise<RedeemOfflineTokenResult> {
    if (!Number.isFinite(params.token.amount) || params.token.amount <= 0) {
      throw new Error('Offline token amount is invalid');
    }

    return this.walletRepository.redeemOfflineToken(params);
  }
}
