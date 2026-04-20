import { Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { TransactionService } from '../services/transaction.service';

const createTransactionSchema = z.object({
  receiverUserId: z.string().uuid(),
  amount: z.number().positive(),
});

const transactionService = new TransactionService();

export class TransactionController {
  async list(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;

    if (!userId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const transactions = await transactionService.listTransactions(userId);
    return res.status(200).json({ transactions });
  }

  async create(req: AuthenticatedRequest, res: Response) {
    const senderUserId = req.auth?.userId;

    if (!senderUserId) {
      return res.status(401).json({
        message: 'Unauthorized',
      });
    }

    const payload = createTransactionSchema.parse(req.body);
    const transaction = await transactionService.createTransaction({
      senderUserId,
      receiverUserId: payload.receiverUserId,
      amount: payload.amount,
    });

    return res.status(201).json(transaction);
  }
}
