import { Logger } from '@nestjs/common';
import { Processor, WorkerHost } from '@nestjs/bullmq';
import type { Job } from 'bullmq';
import { RealtimeBroadcaster } from '@libs/socket';
import { QUEUE } from '@libs/queue';

/**
 * 로비 브로드캐스트 컨슈머 (S2-4) — `domain-events` 큐를 구독해 방 소켓 룸에 실시간 이벤트를 발신한다.
 *
 * 발행(S2-5, 커밋 후 인프로세스) → 이 워커가 잡 이름으로 라우팅 → 브로드캐스터(같은 방에 참여한 소켓들에게 emit).
 * 브로드캐스터의 io 서버는 `LobbyGateway.afterInit`이 바인딩한다(포트를 `useExisting` 싱글턴으로 공유).
 */
@Processor(QUEUE.DOMAIN_EVENTS)
export class LobbyBroadcastProcessor extends WorkerHost {
  private readonly logger = new Logger(LobbyBroadcastProcessor.name);

  constructor(private readonly broadcaster: RealtimeBroadcaster) {
    super();
  }

  async process(job: Job): Promise<void> {
    const roomId = Number(job.data?.roomId);
    if (!roomId) return;

    switch (job.name) {
      case 'ParticipantJoined':
        this.broadcaster.toRoom(roomId, 'participantJoined', { userId: job.data.userId });
        break;
      case 'ParticipantLeft':
        this.broadcaster.toRoom(roomId, 'participantLeft', { userId: job.data.userId });
        break;
      case 'RoomStarting':
        this.broadcaster.toRoom(roomId, 'roomStatusChanged', { status: 'starting' });
        break;
      case 'RoomLive':
        this.broadcaster.toRoom(roomId, 'roomStatusChanged', { status: 'live' });
        break;
      case 'RoomCancelled':
        this.broadcaster.toRoom(roomId, 'roomCancelled', {});
        break;
      default:
        // RoomCreated 등 로비 미소비 이벤트는 무시(다른 컨슈머 소관).
        break;
    }
  }
}
