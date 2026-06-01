import { Request, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth.middleware';
import { AuthService } from '../services/auth.service';

const registerSchema = z.object({
  name: z.string().min(1),
  phone: z.string().min(10),
  password: z.string().min(6),
});

const loginSchema = z.object({
  phone: z.string().min(10),
  password: z.string().min(6),
});

const demoSessionSchema = z.object({
  deviceId: z.string().min(3),
  name: z.string().min(1),
  publicKey: z.string().min(1),
});

const registerKeySchema = z.object({
  public_key: z.string().min(1),
});

const authService = new AuthService();

export class AuthController {
  async demoSession(req: Request, res: Response) {
    const payload = demoSessionSchema.parse(req.body);
    const result = await authService.demoSession(payload);
    return res.status(200).json(result);
  }

  async register(req: Request, res: Response) {
    const payload = registerSchema.parse(req.body);
    const result = await authService.register(payload);
    return res.status(201).json(result);
  }

  async login(req: Request, res: Response) {
    const payload = loginSchema.parse(req.body);
    const result = await authService.login(payload);
    return res.status(200).json(result);
  }

  async registerKey(req: AuthenticatedRequest, res: Response) {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const payload = registerKeySchema.parse(req.body);
    const user = await authService.registerKey({
      userId,
      publicKey: payload.public_key,
    });
    return res.status(200).json({ user });
  }
}
