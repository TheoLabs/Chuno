import { Injectable } from '@nestjs/common';
import { RealtimeBroadcaster } from '@libs/socket';
import { DomainEventHandler } from '@libs/queue';

/** 로비가 브로드캐스트하는 방 도메인 이벤트들. */
const LOBBY_EVENTS = new Set(['ParticipantJoined', 'ParticipantLeft', 'RoomStarting', 'RoomLive', 'RoomCancelled']);

/**
 * 로비 브로드캐스트 핸들러 (S2-4 → S3-3 리팩터: 기존 `LobbyBroadcastProcessor` 로직 이관).
 *
 * `domain-events` 큐의 단일 워커(`DomainEventDispatcher`)가 팬아웃해 호출한다. 방 상태 변화를
 * 같은 방 소켓 룸(기본 네임스페이스)으로 발신한다. 브로드캐스트 매핑은 종전과 동일.
 * 브로드캐스터의 io 서버는 `LobbyGateway.afterInit`이 바인딩한다(루트 ns 싱글턴 공유).
 */
@Injectable()
export class LobbyBroadcastHandler extends DomainEventHandler {
  constructor(private readonly broadcaster: RealtimeBroadcaster) {
    super();
  }

  supports(eventName: string): boolean {
    return LOBBY_EVENTS.has(eventName);
  }

  async handle(eventName: string, data: Record<string, unknown>): Promise<void> {
    const roomId = Number(data?.roomId);
    if (!roomId) return;

    switch (eventName) {
      case 'ParticipantJoined':
        this.broadcaster.toRoom(roomId, 'participantJoined', { userId: data.userId });
        break;
      case 'ParticipantLeft':
        this.broadcaster.toRoom(roomId, 'participantLeft', { userId: data.userId });
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
        break;
    }
  }
}
