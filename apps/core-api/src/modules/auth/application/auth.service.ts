import { Injectable } from '@nestjs/common';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { SocialLoginService } from './social-login.service';
import { AuthTokenService, TokenPair } from './auth-token.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly socialLogin: SocialLoginService,
    private readonly tokens: AuthTokenService
  ) {}

  // 소셜 토큰 검증 → User 해소/생성 → 액세스+리프레시 발급.
  async loginWithSocial(provider: AuthProvider, token: string): Promise<TokenPair> {
    const identity = await this.socialLogin.verify(provider, token);
    const user = await this.socialLogin.resolveOrCreateUser(identity);
    return this.tokens.issuePair(user.id);
  }

  refresh(refreshToken: string): Promise<TokenPair> {
    return this.tokens.rotate(refreshToken);
  }

  async logout(refreshToken: string): Promise<void> {
    await this.tokens.revokeByRefresh(refreshToken);
  }
}
