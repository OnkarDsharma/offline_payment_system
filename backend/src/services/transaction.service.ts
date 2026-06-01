import { UserRepository } from '../repositories/user.repository';
import { OfflineSyncTransactionInput, TransactionRepository } from '../repositories/transaction.repository';

export type CreateTransactionPayload = {
  senderUserId: string;
  receiverUserId: string;
  amount: number;
};

export class TransactionService {
  private readonly userRepository = new UserRepository();
  private readonly transactionRepository = new TransactionRepository();

  async listTransactions(userId: string) {
    return this.transactionRepository.findByUserId(userId);
  }

  async createTransaction(payload: CreateTransactionPayload) {
    if (payload.senderUserId === payload.receiverUserId) {
      throw new Error('Sender and receiver cannot be the same user');
    }

    const receiver = await this.userRepository.findById(payload.receiverUserId);
    if (!receiver) {
      throw new Error('Receiver user not found');
    }

    return this.transactionRepository.createOnlineTransfer(payload);
  }

  async syncTransactions(params: {
    currentUserId: string;
    transactions: OfflineSyncTransactionInput[];
  }) {
    return this.transactionRepository.syncOfflineTransactions(params);
  }
}
