import { Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { TransactionService } from '../services/transaction.service';

const createTransactionSchema = z.object({
  receiverUserId: z.string().uuid(),
  amount: z.number().int().positive(),
});

const syncTransactionsSchema = z.object({
  transactions: z.array(
    z.object({
      transaction_id: z.string().uuid(),
      from_user_id: z.string().uuid(),
      to_user_id: z.string().uuid(),
      amount: z.number().int().positive(),
      currency: z.string().min(1),
      timestamp: z.string().datetime(),
      from_public_key: z.string().min(1),
      signature: z.string().min(1),
    }),
  ),
});

const transactionService = new TransactionService();

export class TransactionController {
  async list(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const transactions = await transactionService.listTransactions(userId);
    return res.status(200).json({
      transactions: transactions.map((transaction) => ({
        transaction_id: transaction.transactionId,
        from_user_id: transaction.fromUserId,
        to_user_id: transaction.toUserId,
        amount: transaction.amount,
        currency: transaction.currency,
        timestamp: transaction.timestamp,
        from_public_key: transaction.fromPublicKey,
        signature: transaction.signature,
        direction: transaction.direction,
        status: transaction.status,
        rejection_reason: transaction.rejectionReason,
        created_at: transaction.createdAt,
      })),
    });
  }

  async create(req: AuthenticatedRequest, res: Response) {
    const senderUserId = req.auth?.userId;
    if (!senderUserId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const payload = createTransactionSchema.parse(req.body);
    const transaction = await transactionService.createTransaction({
      senderUserId,
      receiverUserId: payload.receiverUserId,
      amount: payload.amount,
    });

    return res.status(201).json(transaction);
  }

  async sync(req: AuthenticatedRequest, res: Response) {
    const currentUserId = req.auth?.userId;
    if (!currentUserId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const payload = syncTransactionsSchema.parse(req.body);
    const result = await transactionService.syncTransactions({
      currentUserId,
      transactions: payload.transactions.map((transaction) => ({
        transactionId: transaction.transaction_id,
        fromUserId: transaction.from_user_id,
        toUserId: transaction.to_user_id,
        amount: transaction.amount,
        currency: transaction.currency,
        timestamp: transaction.timestamp,
        fromPublicKey: transaction.from_public_key,
        signature: transaction.signature,
      })),
    });

    return res.status(200).json({
      results: result.results.map((item) => ({
        transaction_id: item.transactionId,
        status: item.status,
        rejection_reason: item.rejectionReason,
      })),
      updated_balances: {
        online_balance: result.updatedBalances.onlineBalance,
        offline_balance: result.updatedBalances.offlineBalance,
      },
    });
  }
}
