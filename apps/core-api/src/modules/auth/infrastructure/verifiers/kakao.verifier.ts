import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { SocialVerifier, VerifiedSubject } from './social-verifier';

type KakaoUserResponse = {
  id: number;
  kakao_account?: { email?: string };
};

@Injectable()
export class KakaoVerifier implements SocialVerifier {
  readonly provider = AuthProvider.KAKAO;

  async verify(token: string): Promise<VerifiedSubject> {
    const res = await fetch('https://kapi.kakao.com/v2/user/me', {
      headers: { Authorization: `Bearer ${token}` },
    });

    if (!res.ok) {
      throw new UnauthorizedException('유효하지 않은 Kakao 토큰입니다.');
    }

    const data = (await res.json()) as KakaoUserResponse;
    return { sub: String(data.id), email: data.kakao_account?.email };
  }
}
