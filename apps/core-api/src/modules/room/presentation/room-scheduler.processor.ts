import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { QUEUE } from '@libs/queue';
import { runWithContext } from '@libs/context';
import { GeneralRoomService } from '@modules/room/applications/general-room.service';

/**
 * 예약 스케줄러 컨슈머 (S2-3) — `room-scheduler` 큐의 지연잡을 소비해 방 상태를 자동 전환한다.
 *
 * - `markStarting` @ `scheduledStartOn − 10s` → RECRUITING→STARTING (또는 2명 미만이면 CANCELLED)
 * - `markLive`     @ `scheduledStartOn`       → STARTING→LIVE
 *
 * 도메인 메서드가 멱등하고 방 부재를 관용하므로, 재시작·중복 잡·롤백된 방에도 이중전환/오류가 없다.
 * 전환 시 발행되는 도메인 이벤트(RoomStarting/RoomLive/RoomCancelled)는 커밋 후 로비로 브로드캐스트된다.
 */
@Processor(QUEUE.ROOM_SCHEDULER)
export class RoomSchedulerProcessor extends WorkerHost {
  constructor(private readonly rooms: GeneralRoomService) {
    super();
  }

  async process(job: Job): Promise<void> {
    const roomId = Number(job.data?.roomId);
    if (!roomId) return;

    // 워커 경계 — ALS 스토어를 열어 @Transactional(markStarting/markLive)이 동작하게 한다.
    await runWithContext(async () => {
      if (job.name === 'markStarting') {
        await this.rooms.markStarting(roomId);
      } else if (job.name === 'markLive') {
        await this.rooms.markLive(roomId);
      }
    });
  }
}
