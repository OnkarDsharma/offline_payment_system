import { Router } from 'express';
import { AuthController } from '../controllers/auth.controller';
import { requireAuth } from '../middleware/auth.middleware';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const controller = new AuthController();

router.post('/demo-session', asyncHandler((req, res) => controller.demoSession(req, res)));
router.post('/register', asyncHandler((req, res) => controller.register(req, res)));
router.post('/login', asyncHandler((req, res) => controller.login(req, res)));
router.post('/register-key', requireAuth, asyncHandler((req, res) => controller.registerKey(req, res)));

export default router;
