import { Injectable, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
import { ConfigsService } from '@configs';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { SocialVerifier, VerifiedSubject } from './social-verifier';

@Injectable()
export class GoogleVerifier implements SocialVerifier {
  readonly provider = AuthProvider.GOOGLE;
  private readonly client = new OAuth2Client();

  constructor(private readonly configs: ConfigsService) {}

  async verify(token: string): Promise<VerifiedSubject> {
    const ticket = await this.client.verifyIdToken({
      idToken: token,
      audience: this.configs.google.mobile.clientId,
    });

    const payload = ticket.getPayload();
    if (!payload?.sub) {
      throw new UnauthorizedException('유효하지 않은 Google 토큰입니다.');
    }

    return { sub: payload.sub, email: payload.email };
  }
}
