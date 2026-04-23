import { UserRepository } from '../repositories/user.repository';
import { hashPassword, verifyPassword } from '../utils/password';
import { signAuthToken } from '../utils/jwt';

export type RegisterPayload = {
  name: string;
  email: string;
  password: string;
  publicKey: string;
};

export type LoginPayload = {
  email: string;
  password: string;
};

export type DemoSessionPayload = {
  deviceId: string;
  name: string;
  publicKey: string;
};

export class AuthService {
  private readonly userRepository = new UserRepository();

  async demoSession(payload: DemoSessionPayload) {
    const demoEmail = `demo_${payload.deviceId.toLowerCase()}@offline.local`;
    const existingUser = await this.userRepository.findByEmail(demoEmail);

    if (existingUser) {
      return {
        user: {
          id: existingUser.id,
          name: existingUser.name,
          email: existingUser.email,
          publicKey: existingUser.publicKey,
        },
        token: signAuthToken({
          sub: existingUser.id,
          email: existingUser.email,
        }),
      };
    }

    const user = await this.userRepository.createWithWallet({
      name: payload.name,
      email: demoEmail,
      passwordHash: hashPassword(`demo_${payload.deviceId}`),
      publicKey: payload.publicKey,
    });

    return {
      user,
      token: signAuthToken({
        sub: user.id,
        email: user.email,
      }),
    };
  }

  async register(payload: RegisterPayload) {
    const existingUser = await this.userRepository.findByEmail(payload.email);

    if (existingUser) {
      throw new Error('An account with this email already exists');
    }

    const user = await this.userRepository.createWithWallet({
      name: payload.name,
      email: payload.email,
      passwordHash: hashPassword(payload.password),
      publicKey: payload.publicKey,
    });

    return {
      user,
      token: signAuthToken({
        sub: user.id,
        email: user.email,
      }),
    };
  }

  async login(payload: LoginPayload) {
    const user = await this.userRepository.findByEmail(payload.email);

    if (!user || !verifyPassword(payload.password, user.passwordHash)) {
      throw new Error('Invalid email or password');
    }

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        publicKey: user.publicKey,
      },
      token: signAuthToken({
        sub: user.id,
        email: user.email,
      }),
    };
  }
}
