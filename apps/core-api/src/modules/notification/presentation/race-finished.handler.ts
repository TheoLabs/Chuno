import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { RaceNotificationService } from '@modules/notification/applications/race-notification.service';

/**
 * 결과 도착 알림 핸들러 (S5-1) — `RaceFinished`를 소비해 참가 러너 전원에게 결과 푸시.
 *
 * 스코어링 핸들러(ScoringResultHandler·RunnerStatsHandler)와 **함께** 같은 RaceFinished에 팬아웃된다. 멱등.
 */
@Injectable()
export class RaceFinishedHandler extends DomainEventHandler {
  constructor(private readonly raceNotifications: RaceNotificationService) {
    super();
  }

  supports(eventName: string): boolean {
    return eventName === 'RaceFinished';
  }

  async handle(_eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;
    await this.raceNotifications.notifyResultReady(roomId);
  }
}
