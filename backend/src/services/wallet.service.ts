import { WalletBalances } from '../models/types';
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

  async mintOfflineTokens(userId: string, amount: number) {
    return this.walletRepository.mintOfflineToken(userId, amount);
  }

  async listOfflineTokens(userId: string, status?: string) {
    return this.walletRepository.listOfflineTokens(userId, status);
  }

  async syncOfflineTokenSpent(userId: string, tokenId: string) {
    return this.walletRepository.syncOfflineTokenSpent(userId, tokenId);
  }

  async redeemOfflineToken(currentUserId: string, tokenPayload: { id: string; ownerUserId: string; amount: number; signature: string; issuedAt: string; }) {
    return this.walletRepository.redeemOfflineToken(currentUserId, tokenPayload);
  }
}
