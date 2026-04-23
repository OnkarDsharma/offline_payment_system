import { Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { WalletService } from '../services/wallet.service';

const walletService = new WalletService();
const mintOfflineTokensSchema = z.object({
  amount: z.number().positive(),
});

const listOfflineTokensSchema = z.object({
  status: z.enum(['ISSUED', 'SPENT', 'REDEEMED', 'REVOKED']).optional(),
});

const syncOfflineTokenSpentSchema = z.object({
  tokenId: z.string().uuid(),
});

const redeemOfflineTokenSchema = z.object({
  token: z.object({
    id: z.string().uuid(),
    ownerUserId: z.string().uuid(),
    amount: z.number().positive(),
    signature: z.string().min(10),
    issuedAt: z.string().min(1),
  }),
});

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

  async mintOfflineTokens(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;

    if (!userId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const payload = mintOfflineTokensSchema.parse(req.body);
    const result = await walletService.mintOfflineTokens({
      userId,
      amount: payload.amount,
    });

    return res.status(201).json(result);
  }

  async listOfflineTokens(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;

    if (!userId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const parsedQuery = listOfflineTokensSchema.parse(req.query);
    const tokens = await walletService.listOfflineTokens({
      userId,
      status: parsedQuery.status,
    });

    return res.status(200).json({ tokens });
  }

  async syncOfflineTokenSpent(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;

    if (!userId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const payload = syncOfflineTokenSpentSchema.parse(req.body);
    const result = await walletService.syncOfflineTokenSpent({
      userId,
      tokenId: payload.tokenId,
    });

    return res.status(200).json(result);
  }

  async redeemOfflineToken(req: AuthenticatedRequest, res: Response) {
    const receiverUserId = req.auth?.userId;

    if (!receiverUserId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const payload = redeemOfflineTokenSchema.parse(req.body);
    const result = await walletService.redeemOfflineToken({
      receiverUserId,
      token: payload.token,
    });

    return res.status(200).json(result);
  }
}
