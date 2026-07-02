import { AuthService } from './auth.service';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';

describe('AuthService', () => {
  const makeService = () => {
    const socialLogin = { verify: jest.fn(), resolveOrCreateUser: jest.fn() };
    const tokens = { issuePair: jest.fn(), rotate: jest.fn(), revokeByRefresh: jest.fn() };
    const service = new AuthService(socialLogin as never, tokens as never);
    return { service, socialLogin, tokens };
  };

  it('loginWithSocial: 검증→User 해소→토큰 발급 순으로 위임한다', async () => {
    const { service, socialLogin, tokens } = makeService();
    const identity = { provider: AuthProvider.GOOGLE, sub: 'g-1' };
    socialLogin.verify.mockResolvedValue(identity);
    socialLogin.resolveOrCreateUser.mockResolvedValue({ id: 99 });
    tokens.issuePair.mockResolvedValue({ accessToken: 'a', refreshToken: 'r' });

    const pair = await service.loginWithSocial(AuthProvider.GOOGLE, 'id-token');

    expect(socialLogin.verify).toHaveBeenCalledWith(AuthProvider.GOOGLE, 'id-token');
    expect(socialLogin.resolveOrCreateUser).toHaveBeenCalledWith(identity);
    expect(tokens.issuePair).toHaveBeenCalledWith(99);
    expect(pair).toEqual({ accessToken: 'a', refreshToken: 'r' });
  });

  it('refresh/logout는 AuthTokenService에 위임한다', async () => {
    const { service, tokens } = makeService();
    await service.refresh('rt');
    await service.logout('rt');
    expect(tokens.rotate).toHaveBeenCalledWith('rt');
    expect(tokens.revokeByRefresh).toHaveBeenCalledWith('rt');
  });
});
