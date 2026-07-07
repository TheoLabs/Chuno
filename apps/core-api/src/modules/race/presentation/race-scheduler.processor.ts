import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { QUEUE } from '@libs/queue';
import { runWithContext } from '@libs/context';
import { RaceService } from '@modules/race/applications/race.service';

/**
 * 경주 스케줄러 컨슈머 (S3-6) — `race-scheduler` 큐의 제한시간 만료 지연잡을 소비해 경주를 마감한다.
 *
 * `finalize` @ `startedAt + limitMinutes` → RaceService.finalize(roomId).
 * 도메인 finalize가 멱등하므로, 전원 완주로 조기 종료된 경우/재시작/중복 잡에도 결과 불변(no-op).
 */
@Processor(QUEUE.RACE_SCHEDULER)
export class RaceSchedulerProcessor extends WorkerHost {
  constructor(private readonly races: RaceService) {
    super();
  }

  async process(job: Job): Promise<void> {
    const roomId = Number(job.data?.roomId);
    if (!roomId) return;
    if (job.name !== 'finalize') return;

    // 워커 경계 — ALS 스토어를 열어 @Transactional(finalize)이 동작하게 한다.
    await runWithContext(async () => {
      await this.races.finalize(roomId);
    });
  }
}
