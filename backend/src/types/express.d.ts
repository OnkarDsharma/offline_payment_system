import 'express';

declare global {
  namespace Express {
    interface Request {
      auth?: {
        userId: string;
        phone: string;
      };
    }
  }
}

export {};
