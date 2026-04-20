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
}
