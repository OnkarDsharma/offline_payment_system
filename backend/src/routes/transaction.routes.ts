import { Router } from 'express';
import { TransactionController } from '../controllers/transaction.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const controller = new TransactionController();

router.get('/', requireAuth, asyncHandler((req, res) => controller.list(req, res)));
router.post('/', requireAuth, asyncHandler((req, res) => controller.create(req, res)));

export default router;
