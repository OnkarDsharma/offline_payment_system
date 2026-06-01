import { Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { WalletService } from '../services/wallet.service';

const walletService = new WalletService();

const mintSchema = z.object({ amount: z.number().positive() });
const syncSpentSchema = z.object({ tokenId: z.string().uuid() });
const redeemSchema = z.object({
  token: z.object({
    id: z.string().uuid(),
    ownerUserId: z.string().uuid(),
    amount: z.number().positive(),
    signature: z.string().min(1),
    issuedAt: z.string().min(1),
  }),
});

export class WalletController {
  async getWallet(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const wallet = await walletService.getWallet(userId);
    return res.status(200).json({
      online_balance: wallet.onlineBalance,
      offline_balance: wallet.offlineBalance,
    });
  }

  async mintOfflineTokens(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;
    if (!userId) return res.status(401).json({ message: 'Unauthorized' });

    const payload = mintSchema.parse(req.body);
    const result = await walletService.mintOfflineTokens(userId, payload.amount);

    return res.status(201).json({
      wallet: {
        user_id: result.wallet.userId,
        online_balance: result.wallet.onlineBalance,
        offline_balance: result.wallet.offlineBalance,
      },
      tokens: [
        {
          id: result.token.id,
          ownerUserId: result.token.ownerUserId,
          amount: result.token.amount,
          status: result.token.status,
          signature: result.token.signature,
          issuedAt: result.token.issuedAt,
          spentAt: result.token.spentAt,
          redeemedAt: result.token.redeemedAt,
        },
      ],
    });
  }

  async listOfflineTokens(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;
    if (!userId) return res.status(401).json({ message: 'Unauthorized' });

    const status = (req.query.status as string) || undefined;
    const tokens = await walletService.listOfflineTokens(userId, status);
    return res.status(200).json({
      tokens: tokens.map((t) => ({
        id: t.id,
        ownerUserId: t.ownerUserId,
        amount: t.amount,
        status: t.status,
        signature: t.signature,
        issuedAt: t.issuedAt,
        spentAt: t.spentAt,
        redeemedAt: t.redeemedAt,
      })),
    });
  }

  async syncOfflineTokenSpent(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;
    if (!userId) return res.status(401).json({ message: 'Unauthorized' });

    const payload = syncSpentSchema.parse(req.body);
    const token = await walletService.syncOfflineTokenSpent(userId, payload.tokenId);
    return res.status(200).json({ token: {
      id: token.id,
      ownerUserId: token.ownerUserId,
      amount: token.amount,
      status: token.status,
      signature: token.signature,
      issuedAt: token.issuedAt,
      spentAt: token.spentAt,
      redeemedAt: token.redeemedAt,
    } });
  }

  async redeemOfflineToken(req: AuthenticatedRequest, res: Response) {
    const currentUserId = req.auth?.userId;
    if (!currentUserId) return res.status(401).json({ message: 'Unauthorized' });

    const payload = redeemSchema.parse(req.body);
    const result = await walletService.redeemOfflineToken(currentUserId, payload.token);

    return res.status(200).json({
      wallet: {
        user_id: result.wallet.userId,
        online_balance: result.wallet.onlineBalance,
        offline_balance: result.wallet.offlineBalance,
      },
      token: {
        id: result.token.id,
        ownerUserId: result.token.ownerUserId,
        amount: result.token.amount,
        status: result.token.status,
        signature: result.token.signature,
        issuedAt: result.token.issuedAt,
        spentAt: result.token.spentAt,
        redeemedAt: result.token.redeemedAt,
      },
      transaction: {
        id: result.transaction.id,
        status: result.transaction.status,
      },
    });
  }
}
