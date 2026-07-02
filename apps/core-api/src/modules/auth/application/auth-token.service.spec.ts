import { UnauthorizedException } from '@nestjs/common';
import { AuthTokenService } from './auth-token.service';
import { RefreshToken } from '../domain/refresh-token.entity';
import { CalendarDate } from '@libs/types';

const FUTURE = '2999-01-01 00:00:00' as CalendarDate;
const PAST = '2000-01-01 00:00:00' as CalendarDate;

const makeService = () => {
  const jwt = { sign: jest.fn().mockReturnValue('access-jwt') };
  const configs = { jwt: { refreshExpiresInDays: 30 } };
  const repo = { findByHash: jest.fn(), findByFamily: jest.fn(), save: jest.fn() };
  const service = new AuthTokenService(jwt as never, configs as never, repo as never);
  return { service, jwt, repo };
};

const token = (over: Partial<RefreshToken> = {}) => {
  const t = RefreshToken.issue({ userId: 7, tokenHash: 'h', familyId: 'fam', expiresOn: FUTURE });
  Object.assign(t, over);
  return t;
};

describe('AuthTokenService', () => {
  describe('issuePair', () => {
    it('새 계열의 리프레시를 저장하고 access+refresh를 발급한다', async () => {
      const { service, repo } = makeService();
      const pair = await service.issuePair(42);

      expect(pair.accessToken).toBe('access-jwt');
      expect(pair.refreshToken).toMatch(/^[0-9a-f]{64}$/); // opaque hex
      expect(repo.save).toHaveBeenCalledTimes(1);
      const [saved] = repo.save.mock.calls[0] as [RefreshToken[]];
      expect(saved).toHaveLength(1);
      expect(saved[0].userId).toBe(42);
      expect(saved[0].tokenHash).toHaveLength(64); // sha256 hex
      expect(saved[0].tokenHash).not.toBe(pair.refreshToken); // 원문 아닌 해시 저장
    });
  });

  describe('rotate', () => {
    it('유효한 리프레시를 회전한다(기존 rotated, 같은 계열로 새 토큰 발급)', async () => {
      const { service, repo } = makeService();
      const old = token({ familyId: 'fam-1' });
      repo.findByHash.mockResolvedValue(old);

      const pair = await service.rotate('presented');

      expect(old.rotated).toBe(true);
      const [saved] = repo.save.mock.calls[0] as [RefreshToken[]];
      expect(saved[0]).toBe(old);
      expect(saved[1].familyId).toBe('fam-1'); // 같은 계열 승계
      expect(saved[1].rotated).toBe(false);
      expect(pair.refreshToken).toMatch(/^[0-9a-f]{64}$/);
    });

    it('존재하지 않는 리프레시는 401', async () => {
      const { service, repo } = makeService();
      repo.findByHash.mockResolvedValue(null);
      await expect(service.rotate('x')).rejects.toBeInstanceOf(UnauthorizedException);
    });

    it('재사용 감지(이미 회전된 토큰) → 계열 전체 무효화 + 401', async () => {
      const { service, repo } = makeService();
      const used = token({ familyId: 'fam-2' });
      used.markRotated();
      repo.findByHash.mockResolvedValue(used);
      repo.findByFamily.mockResolvedValue([used]);

      await expect(service.rotate('x')).rejects.toBeInstanceOf(UnauthorizedException);

      expect(repo.findByFamily).toHaveBeenCalledWith('fam-2');
      expect(used.revoked).toBe(true);
      expect(repo.save).toHaveBeenCalledWith([used]);
    });

    it('폐기된 토큰 재사용도 계열 무효화 + 401', async () => {
      const { service, repo } = makeService();
      const revoked = token({ familyId: 'fam-3' });
      revoked.markRevoked();
      repo.findByHash.mockResolvedValue(revoked);
      repo.findByFamily.mockResolvedValue([revoked]);

      await expect(service.rotate('x')).rejects.toBeInstanceOf(UnauthorizedException);
      expect(repo.findByFamily).toHaveBeenCalledWith('fam-3');
    });

    it('만료된 리프레시는 폐기 후 401', async () => {
      const { service, repo } = makeService();
      const expired = token({ expiresOn: PAST });
      repo.findByHash.mockResolvedValue(expired);

      await expect(service.rotate('x')).rejects.toBeInstanceOf(UnauthorizedException);
      expect(expired.revoked).toBe(true);
      expect(repo.save).toHaveBeenCalledWith([expired]);
    });
  });

  describe('revokeByRefresh (logout)', () => {
    it('제시된 리프레시의 계열 전체를 폐기한다', async () => {
      const { service, repo } = makeService();
      const t = token({ familyId: 'fam-9' });
      repo.findByHash.mockResolvedValue(t);
      repo.findByFamily.mockResolvedValue([t]);

      await service.revokeByRefresh('x');

      expect(repo.findByFamily).toHaveBeenCalledWith('fam-9');
      expect(t.revoked).toBe(true);
      expect(repo.save).toHaveBeenCalledWith([t]);
    });

    it('없는 토큰이면 조용히 무시', async () => {
      const { service, repo } = makeService();
      repo.findByHash.mockResolvedValue(null);
      await expect(service.revokeByRefresh('x')).resolves.toBeUndefined();
      expect(repo.save).not.toHaveBeenCalled();
    });
  });
});
