import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { CalendarDate } from '@libs/types';
import { toEpochMs } from '@libs/date';
import { QUEUE } from '@libs/queue';

/** STARTING 리드타임 — 예약 정각(LIVE) 10초 전에 참여 마감·카운트다운 시작(Δ=10초 고정). */
export const STARTING_LEAD_MS = 10_000;

/**
 * 방 예약 지연잡 등록/취소 (S2-3) — BullMQ `room-scheduler` 큐.
 *
 * 방 생성 시 두 지연잡을 건다:
 * - `markStarting` @ `scheduledStartOn − 10s` (RECRUITING→STARTING, 2명 미만이면 CANCELLED)
 * - `markLive`     @ `scheduledStartOn`       (STARTING→LIVE)
 *
 * jobId를 방마다 결정적으로 부여해 **취소·재등록**을 가능케 한다. 잡 핸들러(도메인 markStarting/markLive)가
 * 멱등하므로, 취소 누락/재시작에도 이중전환은 없다(잡 취소는 best-effort 최적화).
 */
@Injectable()
export class RoomScheduler {
  constructor(@InjectQueue(QUEUE.ROOM_SCHEDULER) private readonly queue: Queue) {}

  private startingJobId(roomId: number): string {
    return `room:${roomId}:starting`;
  }

  private liveJobId(roomId: number): string {
    return `room:${roomId}:live`;
  }

  /** 방의 STARTING/LIVE 전환 지연잡을 등록(기존 잡은 제거 후 재등록). */
  async schedule(roomId: number, scheduledStartOn: CalendarDate): Promise<void> {
    const liveAt = toEpochMs(scheduledStartOn);
    const startingAt = liveAt - STARTING_LEAD_MS;
    const now = Date.now();

    await this.cancel(roomId); // 재등록 대비 기존 잡 제거

    await this.queue.add(
      'markStarting',
      { roomId },
      { jobId: this.startingJobId(roomId), delay: Math.max(0, startingAt - now), removeOnComplete: true, removeOnFail: 100 }
    );
    await this.queue.add(
      'markLive',
      { roomId },
      { jobId: this.liveJobId(roomId), delay: Math.max(0, liveAt - now), removeOnComplete: true, removeOnFail: 100 }
    );
  }

  /** 방의 예약 잡 제거(취소/삭제 시). 없으면 무시. */
  async cancel(roomId: number): Promise<void> {
    await Promise.all([
      this.queue.remove(this.startingJobId(roomId)).catch(() => undefined),
      this.queue.remove(this.liveJobId(roomId)).catch(() => undefined),
    ]);
  }
}
