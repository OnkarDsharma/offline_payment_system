import { Router } from 'express';
import authRoutes from './auth.routes';
import syncRoutes from './sync.routes';
import transactionRoutes from './transaction.routes';
import walletRoutes from './wallet.routes';

const router = Router();

router.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

router.use('/auth', authRoutes);
router.use('/sync', syncRoutes);
router.use('/wallet', walletRoutes);
router.use('/transactions', transactionRoutes);

export default router;
