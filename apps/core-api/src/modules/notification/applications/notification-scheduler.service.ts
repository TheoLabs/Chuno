import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { CalendarDate } from '@libs/types';
import { toEpochMs } from '@libs/date';
import { QUEUE } from '@libs/queue';

/** 출발 리마인더 리드타임 — 예약 정각 60초 전에 "곧 출발" 알림(T-1분). */
export const START_REMINDER_LEAD_MS = 60_000;

/**
 * 알림 지연잡 스케줄러 (S5-1, 선택) — BullMQ `notification-scheduler` 큐. room-scheduler와 동형 패턴.
 *
 * `scheduledStartOn − 60s` 시점에 "곧 출발" 리마인더를 예약한다. jobId를 방마다 결정적으로 부여해 재등록·취소 가능.
 * 잡 소비 경로는 NotificationService.notify(멱등)를 재호출하므로, 이미 RoomStarting(T-10s) 알림이 나갔다면
 * dedupeKey 충돌로 no-op이 된다(중복 발송 없음) — 리마인더는 누락 대비 안전망이다.
 */
@Injectable()
export class NotificationScheduler {
  constructor(@InjectQueue(QUEUE.NOTIFICATION_SCHEDULER) private readonly queue: Queue) {}

  private reminderJobId(roomId: number): string {
    return `noti:${roomId}:start-reminder`;
  }

  /** `scheduledStartOn − 60s`에 출발 리마인더 지연잡 등록(기존 잡은 제거 후 재등록). */
  async scheduleStartReminder(roomId: number, scheduledStartOn: CalendarDate): Promise<void> {
    const remindAt = toEpochMs(scheduledStartOn) - START_REMINDER_LEAD_MS;
    const delay = Math.max(0, remindAt - Date.now());

    await this.cancel(roomId);
    await this.queue.add(
      'remind',
      { roomId },
      { jobId: this.reminderJobId(roomId), delay, removeOnComplete: true, removeOnFail: 100 }
    );
  }

  /** 방의 리마인더 잡 제거(취소/삭제 시). 없으면 무시. */
  async cancel(roomId: number): Promise<void> {
    await this.queue.remove(this.reminderJobId(roomId)).catch(() => undefined);
  }
}
