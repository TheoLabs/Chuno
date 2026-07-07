import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { QUEUE } from '@libs/queue';

/**
 * 경주 제한시간 만료 지연잡 등록/취소 (S3-6) — BullMQ `race-scheduler` 큐.
 *
 * Race 생성 시 `startedAt + limitMinutes` 시점에 `finalize` 잡을 건다. 잡 핸들러(RaceService.finalize)가
 * **멱등**하므로(이미 FINISHED면 no-op), 전원 완주로 조기 종료된 경우 이 잡은 안전한 no-op이 된다.
 * jobId를 방마다 결정적으로 부여해 취소·재등록을 가능케 한다(취소는 best-effort 최적화).
 */
@Injectable()
export class RaceScheduler {
  constructor(@InjectQueue(QUEUE.RACE_SCHEDULER) private readonly queue: Queue) {}

  private finalizeJobId(roomId: number): string {
    return `race:${roomId}:finalize`;
  }

  /** `startedAt + limitMinutes`에 finalize 지연잡 등록(기존 잡은 제거 후 재등록). */
  async scheduleFinalize(roomId: number, startedAt: Date, limitMinutes: number): Promise<void> {
    const finalizeAt = startedAt.getTime() + limitMinutes * 60_000;
    const delay = Math.max(0, finalizeAt - Date.now());

    await this.cancel(roomId); // 재등록 대비 기존 잡 제거
    await this.queue.add(
      'finalize',
      { roomId },
      { jobId: this.finalizeJobId(roomId), delay, removeOnComplete: true, removeOnFail: 100 }
    );
  }

  /** 경주의 finalize 잡 제거. 없으면 무시. */
  async cancel(roomId: number): Promise<void> {
    await this.queue.remove(this.finalizeJobId(roomId)).catch(() => undefined);
  }
}
