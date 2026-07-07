import { Injectable, Logger } from '@nestjs/common';
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
  private readonly logger = new Logger(SocketIoBroadcaster.name);
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
    // 미바인딩 시 조용히 스킵(throw 아님) — 서버가 안 떠 있으면 수신 대상 소켓도 없다.
    // 재기동 직후 백로그 잡이 바인딩 전에 소비돼도 잡 실패/유실로 번지지 않게 한다.
    if (!this.server) {
      this.logger.warn(`io 미바인딩 — 브로드캐스트 스킵 (room=${roomId}, event=${event})`);
      return;
    }
    this.server.to(roomKey(roomId)).emit(event, payload);
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
