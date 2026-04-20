import { Router } from 'express';
import { AuthController } from '../controllers/auth.controller';
import { asyncHandler } from '../utils/async-handler';

const router = Router();
const controller = new AuthController();

router.post('/register', asyncHandler((req, res) => controller.register(req, res)));
router.post('/login', asyncHandler((req, res) => controller.login(req, res)));

export default router;
