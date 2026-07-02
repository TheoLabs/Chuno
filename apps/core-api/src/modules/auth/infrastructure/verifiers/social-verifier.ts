import { AuthProvider } from '@modules/user/domain/auth-identity.entity';

// 검증기가 provider 토큰에서 뽑아낸 신뢰 가능한 값.
export type VerifiedSubject = {
  sub: string;
  email?: string;
};

// provider별 토큰 검증 포트. 각 어댑터는 자신이 담당하는 provider를 노출한다.
export interface SocialVerifier {
  readonly provider: AuthProvider;
  verify(token: string): Promise<VerifiedSubject>;
}
