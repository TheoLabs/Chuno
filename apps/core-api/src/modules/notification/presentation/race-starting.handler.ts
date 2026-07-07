import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { RaceNotificationService } from '@modules/notification/applications/race-notification.service';
import { NotificationScheduler } from '@modules/notification/applications/notification-scheduler.service';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';

/**
 * 경주 임박 알림 핸들러 (S5-1) — `RoomStarting`(T-10s)을 소비해 참가자에게 "곧 시작" 푸시.
 *
 * 추가로 `scheduledStartOn − 60s` "곧 출발" 리마인더 지연잡을 등록한다(선택·안전망). 리마인더는 같은
 * RACE_STARTING dedupeKey를 재사용하므로, 이 즉시 발송이 성공했다면 중복 없이 no-op이 된다.
 */
@Injectable()
export class RaceStartingHandler extends DomainEventHandler {
  constructor(
    private readonly raceNotifications: RaceNotificationService,
    private readonly notificationScheduler: NotificationScheduler,
    private readonly roomRepository: RoomRepository
  ) {
    super();
  }

  supports(eventName: string): boolean {
    return eventName === 'RoomStarting';
  }

  async handle(_eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;

    await this.raceNotifications.notifyRaceStarting(roomId);

    // 선택적 T-1분 리마인더 지연잡 — scheduledStartOn을 알아야 하므로 방을 로드해 예약.
    const [room] = await this.roomRepository.find({ id: roomId });
    if (room) {
      await this.notificationScheduler.scheduleStartReminder(roomId, room.scheduledStartOn);
    }
  }
}
