import { NextFunction, Request, Response } from 'express';
import { verifyAuthToken } from '../utils/jwt';

export type AuthenticatedRequest = Request & {
  auth?: {
    userId: string;
    email: string;
  };
};

export const requireAuth = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
) => {
  const authorization = req.headers.authorization;

  if (!authorization?.startsWith('Bearer ')) {
    return res.status(401).json({
      message: 'Missing or invalid authorization header',
    });
  }

  const token = authorization.slice('Bearer '.length);

  try {
    const payload = verifyAuthToken(token);
    req.auth = {
      userId: payload.sub,
      email: payload.email,
    };
    return next();
  } catch (_error) {
    return res.status(401).json({
      message: 'Invalid or expired token',
    });
  }
};
