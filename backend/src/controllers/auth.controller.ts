import { Request, Response } from 'express';
import { z } from 'zod';
import { AuthService } from '../services/auth.service';

const registerSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(6),
  publicKey: z.string().min(1),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

const authService = new AuthService();

const toClientMessage = (error: unknown, fallback: string) => {
  if (!(error instanceof Error)) {
    return fallback;
  }

  const raw = error.message.toLowerCase();
  if (raw.includes('password authentication failed for user')) {
    return 'Database authentication failed. Please verify backend DATABASE_URL credentials.';
  }

  return error.message;
};

export class AuthController {
  async register(req: Request, res: Response) {
    try {
      const payload = registerSchema.parse(req.body);
      const result = await authService.register(payload);

      return res.status(201).json(result);
    } catch (error) {
      const message = toClientMessage(error, 'Registration failed');
      return res.status(400).json({ message });
    }
  }

  async login(req: Request, res: Response) {
    try {
      const payload = loginSchema.parse(req.body);
      const result = await authService.login(payload);

      return res.status(200).json(result);
    } catch (error) {
      const message = toClientMessage(error, 'Login failed');
      return res.status(400).json({ message });
    }
  }
}
