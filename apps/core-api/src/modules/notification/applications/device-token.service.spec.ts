import { DeviceTokenService } from './device-token.service';
import { DeviceToken, DevicePlatform } from '@modules/notification/domain/device-token.entity';

/**
 * S5-1 — 기기 토큰 등록(upsert)·해제 검증. 신규 저장 / 중복 토큰 재귀속 / 소유자 불일치 무시.
 */
describe('DeviceTokenService (S5-1)', () => {
  const setup = (existing?: DeviceToken) => {
    const deviceTokenRepository = {
      find: jest.fn().mockResolvedValue(existing ? [existing] : []),
      save: jest.fn().mockResolvedValue(undefined),
      remove: jest.fn().mockResolvedValue(undefined),
    };
    const service = new DeviceTokenService(deviceTokenRepository as never);
    // @Transactional 통과용 최소 컨텍스트(scoring.service.spec 패턴).
    Object.assign(service, {
      context: { set: jest.fn(), get: jest.fn(() => []) },
      entityManager: { transaction: async (cb: (em: unknown) => unknown) => cb({}) },
      eventPublisher: { publish: jest.fn() },
    });
    return { service, deviceTokenRepository };
  };

  it('신규 토큰 → DeviceToken 저장', async () => {
    const { service, deviceTokenRepository } = setup();
    await service.register({ userId: 1, token: 'tok-a', platform: DevicePlatform.IOS });

    expect(deviceTokenRepository.save).toHaveBeenCalledTimes(1);
    const [saved] = deviceTokenRepository.save.mock.calls[0][0];
    expect(saved).toMatchObject({ userId: 1, token: 'tok-a', platform: DevicePlatform.IOS });
  });

  it('중복 토큰 → 소유 유저/플랫폼 갱신(upsert)', async () => {
    const existing = DeviceToken.of({ userId: 1, token: 'tok-a', platform: DevicePlatform.IOS });
    const { service, deviceTokenRepository } = setup(existing);

    await service.register({ userId: 2, token: 'tok-a', platform: DevicePlatform.ANDROID });

    // 새 레코드를 만들지 않고 기존 레코드를 재귀속해 저장.
    expect(deviceTokenRepository.save).toHaveBeenCalledTimes(1);
    const [saved] = deviceTokenRepository.save.mock.calls[0][0];
    expect(saved).toBe(existing);
    expect(saved).toMatchObject({ userId: 2, token: 'tok-a', platform: DevicePlatform.ANDROID });
  });

  it('해제: 소유자 일치 시 제거', async () => {
    const existing = DeviceToken.of({ userId: 7, token: 'tok-x', platform: DevicePlatform.IOS });
    const { service, deviceTokenRepository } = setup(existing);
    await service.unregister({ userId: 7, token: 'tok-x' });
    expect(deviceTokenRepository.remove).toHaveBeenCalledWith([existing]);
  });

  it('해제: 소유자 불일치/미존재면 no-op', async () => {
    const other = DeviceToken.of({ userId: 99, token: 'tok-x', platform: DevicePlatform.IOS });
    const { service: s1, deviceTokenRepository: r1 } = setup(other);
    await s1.unregister({ userId: 7, token: 'tok-x' }); // 남의 토큰
    expect(r1.remove).not.toHaveBeenCalled();

    const { service: s2, deviceTokenRepository: r2 } = setup(); // 없음
    await s2.unregister({ userId: 7, token: 'tok-x' });
    expect(r2.remove).not.toHaveBeenCalled();
  });
});
