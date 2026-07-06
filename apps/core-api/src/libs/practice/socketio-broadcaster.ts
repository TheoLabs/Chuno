import { Injectable } from '@nestjs/common';
import type { Server, Socket } from 'socket.io';
import { RealtimeBroadcaster } from './realtime-broadcaster';
import { RoomRegistry, roomKey } from './room-registry';

/**
 * RealtimeBroadcaster 포트의 socket.io 구현.
 *
 * io `Server` 인스턴스는 게이트웨이가 초기화(afterInit)될 때 {@link bind}로 주입된다.
 * (Nest DI 시점엔 아직 io 서버가 없어서 생성자 주입이 불가능하다.)
 *
 * NOTE: SocketModule에서 `RealtimeBroadcaster`(포트)와 이 클래스를 **같은 인스턴스**로
 * 바인딩(useExisting)한다 — 게이트웨이가 bind한 서버를 소비자(포트 주입)도 공유해야 하기 때문.
 */
@Injectable()
export class SocketIoBroadcaster extends RealtimeBroadcaster {
  private server?: Server;

  /** 게이트웨이 afterInit에서 io 서버를 바인딩한다. */
  bind(server: Server): void {
    this.server = server;
  }

  private get io(): Server {
    if (!this.server) {
      throw new Error('SocketIoBroadcaster: io 서버가 바인딩되지 않았습니다(게이트웨이 afterInit 확인).');
    }
    return this.server;
  }

  toRoom(roomId: number, event: string, payload?: unknown): void {
    this.io.to(roomKey(roomId)).emit(event, payload);
  }

  join(client: Socket, roomId: number): void {
    RoomRegistry.join(client, roomId);
  }

  leave(client: Socket, roomId: number): void {
    RoomRegistry.leave(client, roomId);
  }

  roomSize(roomId: number): Promise<number> {
    return RoomRegistry.size(this.io, roomId);
  }
}
