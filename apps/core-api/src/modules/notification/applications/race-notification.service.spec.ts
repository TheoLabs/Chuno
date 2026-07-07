import { RaceNotificationService } from './race-notification.service';
import { NotiType } from '@modules/notification/domain/notification.entity';

/**
 * S5-1 — 이벤트 payload(roomId)로 방/경주를 로드해 올바른 대상에게 notify 위임하는지 검증.
 */
describe('RaceNotificationService (S5-1)', () => {
  const setup = (opts: { room?: unknown; race?: unknown } = {}) => {
    const roomRepository = { find: jest.fn().mockResolvedValue(opts.room !== undefined ? [opts.room] : []) };
    const raceRepository = { find: jest.fn().mockResolvedValue(opts.race !== undefined ? [opts.race] : []) };
    const notificationService = { notify: jest.fn().mockResolvedValue(undefined) };
    const service = new RaceNotificationService(roomRepository as never, raceRepository as never, notificationService as never);
    return { service, notificationService };
  };

  it('새 참가자 → 방장에게 PARTICIPANT_JOINED', async () => {
    const { service, notificationService } = setup({ room: { id: 5, hostUserId: 100 } });
    await service.notifyParticipantJoined(5, 7);

    expect(notificationService.notify).toHaveBeenCalledTimes(1);
    expect(notificationService.notify.mock.calls[0][0]).toMatchObject({
      userIds: [100],
      type: NotiType.PARTICIPANT_JOINED,
      roomId: 5,
    });
  });

  it('방장 자신의 참가 이벤트는 알리지 않음', async () => {
    const { service, notificationService } = setup({ room: { id: 5, hostUserId: 100 } });
    await service.notifyParticipantJoined(5, 100);
    expect(notificationService.notify).not.toHaveBeenCalled();
  });

  it('경주 임박 → 참가자 전원에게 RACE_STARTING', async () => {
    const room = { id: 5, participants: [{ userId: 1 }, { userId: 2 }] };
    const { service, notificationService } = setup({ room });
    await service.notifyRaceStarting(5);

    expect(notificationService.notify.mock.calls[0][0]).toMatchObject({
      userIds: [1, 2],
      type: NotiType.RACE_STARTING,
      roomId: 5,
    });
  });

  it('결과 도착 → 러너 전원에게 RESULT_READY', async () => {
    const race = { id: 42, runners: [{ userId: 1 }, { userId: 2 }, { userId: 3 }] };
    const { service, notificationService } = setup({ race });
    await service.notifyResultReady(9);

    expect(notificationService.notify.mock.calls[0][0]).toMatchObject({
      userIds: [1, 2, 3],
      type: NotiType.RESULT_READY,
      roomId: 9,
    });
  });

  it('방/경주 없으면 no-op', async () => {
    const { service, notificationService } = setup();
    await service.notifyRaceStarting(1);
    await service.notifyResultReady(1);
    await service.notifyParticipantJoined(1, 2);
    expect(notificationService.notify).not.toHaveBeenCalled();
  });
});
