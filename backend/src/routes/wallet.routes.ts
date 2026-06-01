import { Router } from 'express';
import { WalletController } from '../controllers/wallet.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const controller = new WalletController();

router.get('/balance', requireAuth, asyncHandler((req, res) => controller.getWallet(req, res)));

router.post('/mint-offline-tokens', requireAuth, asyncHandler((req, res) => controller.mintOfflineTokens(req, res)));
router.get('/offline-tokens', requireAuth, asyncHandler((req, res) => controller.listOfflineTokens(req, res)));
router.post('/sync-offline-token-spent', requireAuth, asyncHandler((req, res) => controller.syncOfflineTokenSpent(req, res)));
router.post('/redeem-offline-token', requireAuth, asyncHandler((req, res) => controller.redeemOfflineToken(req, res)));

export default router;
