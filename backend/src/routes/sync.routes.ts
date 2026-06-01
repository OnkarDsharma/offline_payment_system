import { Router } from 'express';
import { TransactionController } from '../controllers/transaction.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const controller = new TransactionController();

router.post('/', requireAuth, asyncHandler((req, res) => controller.sync(req, res)));

export default router;
