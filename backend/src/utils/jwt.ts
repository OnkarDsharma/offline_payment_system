import jwt from 'jsonwebtoken';
import { env } from '../config/env';

export type AuthTokenPayload = {
  sub: string;
  email: string;
};

export const signAuthToken = (payload: AuthTokenPayload) => {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: '1d' });
};

export const verifyAuthToken = (token: string) => {
  return jwt.verify(token, env.JWT_SECRET) as AuthTokenPayload;
};
