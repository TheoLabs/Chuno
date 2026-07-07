import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { RaceBroadcaster } from './race-broadcaster';

/** '/race'로 브로드캐스트하는 경주 도메인 이벤트들. */
const RACE_BROADCAST_EVENTS = new Set(['RunnerFinished', 'RaceFinished']);

/**
 * 경주 브로드캐스트 핸들러 (S3-4/S3-6) — 완주/종료 도메인 이벤트를 '/race' 네임스페이스로 발신한다.
 *
 * `DomainEventDispatcher`가 팬아웃해 호출한다. 리더보드는 게이트웨이 주기 타이머가 담당하고,
 * 여기서는 이벤트성 알림(runnerFinished/raceFinished)만 같은 방 러너들에게 브로드캐스트한다.
 * '/race' 네임스페이스는 `RaceGateway.afterInit`이 브로드캐스터에 바인딩한다(루트 ns와 분리).
 */
@Injectable()
export class RaceBroadcastHandler extends DomainEventHandler {
  constructor(private readonly broadcaster: RaceBroadcaster) {
    super();
  }

  supports(eventName: string): boolean {
    return RACE_BROADCAST_EVENTS.has(eventName);
  }

  async handle(eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;

    switch (eventName) {
      case 'RunnerFinished':
        this.broadcaster.toRoom(roomId, 'runnerFinished', {
          userId: data.userId,
          finishedAt: data.finishedAt,
        });
        break;
      case 'RaceFinished':
        this.broadcaster.toRoom(roomId, 'raceFinished', { roomId });
        break;
      default:
        break;
    }
  }
}
