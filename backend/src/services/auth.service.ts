import { UserRepository } from '../repositories/user.repository';
import { hashPassword, verifyPassword } from '../utils/password';
import { signAuthToken } from '../utils/jwt';

export type RegisterPayload = {
  name: string;
  phone: string;
  password: string;
};

export type LoginPayload = {
  phone: string;
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
    const phone = `9${payload.deviceId.replace(/[^0-9]/g, '').padStart(9, '0').slice(0, 9)}`;
    const existingUser = await this.userRepository.findByPhone(phone);

    if (existingUser) {
      if (existingUser.publicKey !== payload.publicKey) {
        await this.userRepository.updatePublicKey({
          userId: existingUser.id,
          publicKey: payload.publicKey,
        });
      }

      return {
        user: {
          id: existingUser.id,
          name: existingUser.name,
          phone: existingUser.phone,
          publicKey: payload.publicKey,
        },
        token: signAuthToken({
          sub: existingUser.id,
          phone: existingUser.phone,
        }),
      };
    }

    const user = await this.userRepository.createWithWallet({
      name: payload.name,
      phone,
      passwordHash: hashPassword(`demo_${payload.deviceId}`),
      publicKey: payload.publicKey,
    });

    return {
      user,
      token: signAuthToken({
        sub: user.id,
        phone: user.phone,
      }),
    };
  }

  async register(payload: RegisterPayload) {
    const existingUser = await this.userRepository.findByPhone(payload.phone);
    if (existingUser) {
      throw new Error('An account with this phone already exists');
    }

    const user = await this.userRepository.createWithWallet({
      name: payload.name,
      phone: payload.phone,
      passwordHash: hashPassword(payload.password),
      publicKey: null,
    });

    return {
      user,
      token: signAuthToken({
        sub: user.id,
        phone: user.phone,
      }),
    };
  }

  async login(payload: LoginPayload) {
    const user = await this.userRepository.findByPhone(payload.phone);

    if (!user || !verifyPassword(payload.password, user.passwordHash)) {
      throw new Error('Invalid phone or password');
    }

    return {
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        publicKey: user.publicKey,
      },
      token: signAuthToken({
        sub: user.id,
        phone: user.phone,
      }),
    };
  }

  async registerKey(params: { userId: string; publicKey: string }) {
    return this.userRepository.updatePublicKey(params);
  }
}
