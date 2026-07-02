import { UnauthorizedException } from '@nestjs/common';
import { SocialLoginService } from './social-login.service';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';
import { User } from '@modules/user/domain/user.entity';

const makeService = (authDevMode = true) => {
  const verifier = { verify: jest.fn() };
  const registry = { get: jest.fn().mockReturnValue(verifier) };
  const configs = { authDevMode };
  const userRepository = { findBySocialIdentity: jest.fn(), save: jest.fn() };
  const service = new SocialLoginService(registry as never, configs as never, userRepository as never);
  return { service, registry, verifier, userRepository };
};

describe('SocialLoginService', () => {
  describe('verify — AUTH_DEV_MODE', () => {
    it('dev 토큰을 실검증 없이 파싱한다', async () => {
      const { service, registry } = makeService(true);
      const identity = await service.verify(AuthProvider.GOOGLE, 'dev:sub-123:me@x.com');
      expect(identity).toEqual({ provider: AuthProvider.GOOGLE, sub: 'sub-123', email: 'me@x.com' });
      expect(registry.get).not.toHaveBeenCalled();
    });

    it('sub 없는 dev 토큰은 거부한다', async () => {
      const { service } = makeService(true);
      await expect(service.verify(AuthProvider.GOOGLE, 'dev:')).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('dev 모드 off면 dev: 토큰도 실검증 경로로 간다', async () => {
      const { service, registry, verifier } = makeService(false);
      verifier.verify.mockResolvedValue({ sub: 'real', email: undefined });
      await service.verify(AuthProvider.KAKAO, 'dev:x:y');
      expect(registry.get).toHaveBeenCalledWith(AuthProvider.KAKAO);
      expect(verifier.verify).toHaveBeenCalledWith('dev:x:y');
    });
  });

  describe('verify — real', () => {
    it('provider verifier로 검증해 신원을 반환한다', async () => {
      const { service, verifier } = makeService(true);
      verifier.verify.mockResolvedValue({ sub: 'g-1', email: 'g@x.com' });
      const identity = await service.verify(AuthProvider.GOOGLE, 'id-token');
      expect(identity).toEqual({ provider: AuthProvider.GOOGLE, sub: 'g-1', email: 'g@x.com' });
    });
  });

  describe('resolveOrCreateUser', () => {
    it('기존 소셜 신원이 있으면 그 User를 반환하고 생성하지 않는다', async () => {
      const { service, userRepository } = makeService();
      const existing = { id: 7 } as User;
      userRepository.findBySocialIdentity.mockResolvedValue(existing);

      const user = await service.resolveOrCreateUser({ provider: AuthProvider.GOOGLE, sub: 's' });

      expect(user).toBe(existing);
      expect(userRepository.save).not.toHaveBeenCalled();
    });

    it('없으면 온보딩 전 User(nickname/level/onboardedOn=null)를 생성·저장한다', async () => {
      const { service, userRepository } = makeService();
      userRepository.findBySocialIdentity.mockResolvedValue(null);

      const user = await service.resolveOrCreateUser({ provider: AuthProvider.KAKAO, sub: 'k-9' });

      expect(userRepository.save).toHaveBeenCalledWith([user]);
      expect(user.nickname).toBeNull();
      expect(user.level).toBeNull();
      expect(user.onboardedOn).toBeNull();
      expect(user.authIdentity.provider).toBe(AuthProvider.KAKAO);
      expect(user.authIdentity.sub).toBe('k-9');
    });
  });
});
