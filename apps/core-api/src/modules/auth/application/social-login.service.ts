import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigsService } from '@configs';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { User } from '@modules/user/domain/user.entity';
import { UserRepository } from '@modules/user/infrastructure/user.repository';
import { SocialIdentity } from '../domain/social-identity';
import { SocialVerifierRegistry } from '../infrastructure/verifiers/social-verifier.registry';

@Injectable()
export class SocialLoginService {
  constructor(
    private readonly registry: SocialVerifierRegistry,
    private readonly configs: ConfigsService,
    private readonly userRepository: UserRepository
  ) {}

  // provider 토큰 검증 → 신뢰 가능한 소셜 신원. AUTH_DEV_MODE면 dev 토큰 우회 허용.
  async verify(provider: AuthProvider, token: string): Promise<SocialIdentity> {
    const devIdentity = this.tryDevToken(provider, token);
    if (devIdentity) return devIdentity;

    const { sub, email } = await this.registry.get(provider).verify(token);
    return { provider, sub, email };
  }

  // 소셜 신원으로 User 조회, 없으면 온보딩 전 User를 생성한다.
  async resolveOrCreateUser(identity: SocialIdentity): Promise<User> {
    const existing = await this.userRepository.findBySocialIdentity(identity.provider, identity.sub);
    if (existing) {
      return existing;
    }

    const user = User.createFromSocial({ provider: identity.provider, sub: identity.sub });
    await this.userRepository.save([user]);
    return user;
  }

  // "dev:<sub>:<email>" 토큰은 AUTH_DEV_MODE가 켜진 경우에만 실검증 없이 허용(로컬 전용).
  private tryDevToken(provider: AuthProvider, token: string): SocialIdentity | null {
    if (!this.configs.authDevMode || !token.startsWith('dev:')) {
      return null;
    }

    const [, sub, email] = token.split(':');
    if (!sub) {
      throw new UnauthorizedException('유효하지 않은 dev 토큰입니다. 형식: dev:<sub>:<email>');
    }

    return { provider, sub, email: email || undefined };
  }
}
