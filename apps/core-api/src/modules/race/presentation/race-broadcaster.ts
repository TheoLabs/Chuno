import { Injectable, Logger } from '@nestjs/common';
import type { Namespace, Socket } from 'socket.io';
import { roomKey, RoomRegistry } from '@libs/socket';

/**
 * '/race' 네임스페이스 전용 브로드캐스터 (S3-4).
 *
 * 루트 io 서버를 바인딩하는 공용 `SocketIoBroadcaster`(로비=기본 ns)로는 별도 네임스페이스 '/race'에
 * emit이 닿지 않는다. 그래서 RaceGateway가 afterInit에서 받은 '/race' `Namespace`를 여기에 bind하고,
 * 이 브로드캐스터로 같은 방 러너들(소켓 룸 `room:{id}`)에게 발신한다. 방 룸 네이밍은 로비와 동일(roomKey).
 */
@Injectable()
export class RaceBroadcaster {
  private readonly logger = new Logger(RaceBroadcaster.name);
  private namespace?: Namespace;

  /** RaceGateway afterInit에서 '/race' 네임스페이스를 바인딩한다. */
  bind(namespace: Namespace): void {
    this.namespace = namespace;
  }

  toRoom(roomId: number, event: string, payload?: unknown): void {
    if (!this.namespace) {
      this.logger.warn(`'/race' 미바인딩 — 브로드캐스트 스킵 (room=${roomId}, event=${event})`);
      return;
    }
    this.namespace.to(roomKey(roomId)).emit(event, payload);
  }

  join(client: Socket, roomId: number): void {
    RoomRegistry.join(client, roomId);
  }

  leave(client: Socket, roomId: number): void {
    RoomRegistry.leave(client, roomId);
  }
}
