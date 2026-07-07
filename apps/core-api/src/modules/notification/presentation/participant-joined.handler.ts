import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { RaceNotificationService } from '@modules/notification/applications/race-notification.service';

/**
 * 새 참가자 알림 핸들러 (S5-1) — `ParticipantJoined`를 소비해 방장에게 푸시.
 *
 * 디스패처가 로비 브로드캐스트 핸들러와 **둘 다**에 팬아웃한다. 발송은 멱등(dedupeKey).
 */
@Injectable()
export class ParticipantJoinedHandler extends DomainEventHandler {
  constructor(private readonly raceNotifications: RaceNotificationService) {
    super();
  }

  supports(eventName: string): boolean {
    return eventName === 'ParticipantJoined';
  }

  async handle(_eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    const userId = Number(data?.userId);
    if (!roomId || !userId) return;
    await this.raceNotifications.notifyParticipantJoined(roomId, userId);
  }
}
