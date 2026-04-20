import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { WalletService } from '../services/wallet.service';

const walletService = new WalletService();

export class WalletController {
  async getWallet(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;

    if (!userId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const wallet = await walletService.getWallet(userId);

    res.status(200).json(wallet);
  }
}
