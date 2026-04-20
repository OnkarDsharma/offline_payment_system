import { Router } from 'express';
import { WalletController } from '../controllers/wallet.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const controller = new WalletController();

router.get('/', requireAuth, asyncHandler((req, res) => controller.getWallet(req, res)));

export default router;
