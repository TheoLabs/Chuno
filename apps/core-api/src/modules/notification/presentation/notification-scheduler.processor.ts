import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { QUEUE } from '@libs/queue';
import { runWithContext } from '@libs/context';
import { RaceNotificationService } from '@modules/notification/applications/race-notification.service';

/**
 * 알림 스케줄러 컨슈머 (S5-1) — `notification-scheduler` 큐의 출발 리마인더 지연잡을 소비.
 *
 * `remind` @ `scheduledStartOn − 60s` → notifyRaceStarting(roomId). 발송은 멱등(dedupeKey)이라
 * 이미 RoomStarting 알림이 나갔으면 no-op. 워커 경계이므로 runWithContext로 ALS 스토어를 연다(@Transactional 동작).
 */
@Processor(QUEUE.NOTIFICATION_SCHEDULER)
export class NotificationSchedulerProcessor extends WorkerHost {
  constructor(private readonly raceNotifications: RaceNotificationService) {
    super();
  }

  async process(job: Job): Promise<void> {
    const roomId = Number(job.data?.roomId);
    if (!roomId) return;
    if (job.name !== 'remind') return;

    await runWithContext(async () => {
      await this.raceNotifications.notifyRaceStarting(roomId);
    });
  }
}
