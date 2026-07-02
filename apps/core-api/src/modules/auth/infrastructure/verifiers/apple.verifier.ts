import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { ConfigsService } from '@configs';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { SocialVerifier, VerifiedSubject } from './social-verifier';

@Injectable()
export class AppleVerifier implements SocialVerifier {
  readonly provider = AuthProvider.APPLE;
  private readonly jwks = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

  constructor(private readonly configs: ConfigsService) {}

  async verify(token: string): Promise<VerifiedSubject> {
    try {
      const { payload } = await jwtVerify(token, this.jwks, {
        issuer: 'https://appleid.apple.com',
        audience: this.configs.apple.clientId,
      });

      if (!payload.sub) {
        throw new UnauthorizedException('유효하지 않은 Apple 토큰입니다.');
      }

      return {
        sub: payload.sub,
        email: typeof payload.email === 'string' ? payload.email : undefined,
      };
    } catch (e) {
      if (e instanceof UnauthorizedException) throw e;
      throw new UnauthorizedException('유효하지 않은 Apple 토큰입니다.');
    }
  }
}
