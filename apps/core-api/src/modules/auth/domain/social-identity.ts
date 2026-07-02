import { AuthProvider } from '@modules/user/domain/auth-identity.entity';

// provider 토큰 검증으로 얻은, 신뢰 가능한 소셜 신원.
export type SocialIdentity = {
  provider: AuthProvider;
  sub: string;
  email?: string;
};
