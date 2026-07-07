import { NotificationService, NotificationPersister, NotifyRequest } from './notification.service';
import { NotiType } from '@modules/notification/domain/notification.entity';

/**
 * S5-1 — 알림 저장 멱등(NotificationPersister) + 발송 위임(NotificationService).
 */
describe('Notification 발송 (S5-1)', () => {
  const request: NotifyRequest = {
    userIds: [1, 2, 2], // 중복 포함
    type: NotiType.RESULT_READY,
    roomId: 10,
    title: 't',
    body: 'b',
    payload: { roomId: 10 },
  };

  describe('NotificationPersister (멱등 저장)', () => {
    const setup = (existsKeys: string[] = []) => {
      const notificationRepository = {
        existsByDedupeKey: jest.fn((key: string) => Promise.resolve(existsKeys.includes(key))),
        save: jest.fn().mockResolvedValue(undefined),
      };
      const persister = new NotificationPersister(notificationRepository as never);
      Object.assign(persister, {
        context: { set: jest.fn(), get: jest.fn(() => []) },
        entityManager: { transaction: async (cb: (em: unknown) => unknown) => cb({}) },
        eventPublisher: { publish: jest.fn() },
      });
      return { persister, notificationRepository };
    };

    it('미저장 대상만 1건씩 저장하고 저장된 userId 반환(중복 유저 병합)', async () => {
      const { persister, notificationRepository } = setup();
      const saved = await persister.persist(request);

      expect(saved).toEqual([1, 2]); // 중복 제거
      expect(notificationRepository.save).toHaveBeenCalledTimes(2);
      const first = notificationRepository.save.mock.calls[0][0][0];
      expect(first).toMatchObject({ userId: 1, type: NotiType.RESULT_READY, dedupeKey: 'RESULT_READY:room:10:user:1' });
    });

    it('이미 저장된 dedupeKey는 건너뜀(멱등)', async () => {
      const { persister, notificationRepository } = setup(['RESULT_READY:room:10:user:1']);
      const saved = await persister.persist(request);

      expect(saved).toEqual([2]); // 1은 이미 존재 → 제외
      expect(notificationRepository.save).toHaveBeenCalledTimes(1);
    });
  });

  describe('NotificationService (발송 위임)', () => {
    const setup = (persisted: number[], tokens: string[] = []) => {
      const persister = { persist: jest.fn().mockResolvedValue(persisted) };
      const deviceTokenRepository = {
        findByUserIds: jest.fn().mockResolvedValue(tokens.map((token) => ({ token }))),
      };
      const pushSender = { send: jest.fn().mockResolvedValue(undefined) };
      const service = new NotificationService(persister as never, deviceTokenRepository as never, pushSender as never);
      return { service, persister, deviceTokenRepository, pushSender };
    };

    it('새 대상의 기기 토큰으로 멀티캐스트 발송', async () => {
      const { service, deviceTokenRepository, pushSender } = setup([1, 2], ['tok-a', 'tok-b']);
      await service.notify(request);

      expect(deviceTokenRepository.findByUserIds).toHaveBeenCalledWith([1, 2]);
      expect(pushSender.send).toHaveBeenCalledTimes(1);
      expect(pushSender.send.mock.calls[0][0]).toMatchObject({ tokens: ['tok-a', 'tok-b'], title: 't', body: 'b' });
    });

    it('저장된 대상이 없으면(전부 멱등 스킵) 발송 안 함', async () => {
      const { service, deviceTokenRepository, pushSender } = setup([]);
      await service.notify(request);
      expect(deviceTokenRepository.findByUserIds).not.toHaveBeenCalled();
      expect(pushSender.send).not.toHaveBeenCalled();
    });

    it('토큰이 없으면 발송 스킵', async () => {
      const { service, pushSender } = setup([1], []);
      await service.notify(request);
      expect(pushSender.send).not.toHaveBeenCalled();
    });

    it('발송 실패는 비치명(throw 안 함)', async () => {
      const { service, pushSender } = setup([1], ['tok-a']);
      pushSender.send.mockRejectedValue(new Error('fcm down'));
      await expect(service.notify(request)).resolves.toBeUndefined();
    });
  });
});
