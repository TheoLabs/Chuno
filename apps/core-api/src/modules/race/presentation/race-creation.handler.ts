import { Injectable } from '@nestjs/common';
import { DomainEventHandler } from '@libs/queue';
import { RaceService } from '@modules/race/applications/race.service';

/**
 * Race 생성 핸들러 (S3-3) — `RoomLive` 도메인 이벤트를 소비해 Race를 생성한다.
 *
 * `DomainEventDispatcher`(domain-events 큐의 단일 워커)가 팬아웃해 호출한다. RoomLive는 로비 브로드캐스트
 * 핸들러(roomStatusChanged:live)와 이 핸들러 **둘 다**에 팬아웃된다(경쟁 소비 없음). 생성은 멱등.
 */
@Injectable()
export class RaceCreationHandler extends DomainEventHandler {
  constructor(private readonly races: RaceService) {
    super();
  }

  supports(eventName: string): boolean {
    return eventName === 'RoomLive';
  }

  async handle(_eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;
    await this.races.createFromRoom(roomId);
  }
}
