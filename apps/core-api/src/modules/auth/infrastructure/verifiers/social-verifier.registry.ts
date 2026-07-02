import { BadRequestException, Injectable } from '@nestjs/common';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { SocialVerifier } from './social-verifier';
import { GoogleVerifier } from './google.verifier';
import { AppleVerifier } from './apple.verifier';
import { KakaoVerifier } from './kakao.verifier';

@Injectable()
export class SocialVerifierRegistry {
  private readonly verifiers: Map<AuthProvider, SocialVerifier>;

  constructor(google: GoogleVerifier, apple: AppleVerifier, kakao: KakaoVerifier) {
    this.verifiers = new Map<AuthProvider, SocialVerifier>(
      [google, apple, kakao].map((verifier) => [verifier.provider, verifier])
    );
  }

  get(provider: AuthProvider): SocialVerifier {
    const verifier = this.verifiers.get(provider);
    if (!verifier) {
      throw new BadRequestException(`지원하지 않는 provider입니다: ${provider}`);
    }
    return verifier;
  }
}
