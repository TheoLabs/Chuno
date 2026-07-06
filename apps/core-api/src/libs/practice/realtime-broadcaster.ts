import type { Socket } from 'socket.io';

/**
 * 실시간 발행 포트(추상 클래스 = 인터페이스 + DI 토큰).
 *
 * 도메인/애플리케이션 레이어는 **socket.io를 모른 채 이 포트에만 의존**한다.
 * - 전송 구현(socket.io)을 교체하거나
 * - 테스트에서 목(mock)으로 갈아끼우기
 * 가 쉬워진다. (DDD 레이어링: 도메인이 인프라를 import 하지 않는다.)
 *
 * NestJS에서는 추상 클래스를 그대로 DI 토큰으로 쓸 수 있어,
 * `{ provide: RealtimeBroadcaster, useExisting: SocketIoBroadcaster }` 로 바인딩한다.
 */
export abstract class RealtimeBroadcaster {
  /** 특정 방(room)에 참여한 모든 클라이언트에게 이벤트를 브로드캐스트한다. */
  abstract toRoom(roomId: number, event: string, payload?: unknown): void;

  /** 클라이언트를 방에 참여시킨다(socket.io의 room join). */
  abstract join(client: Socket, roomId: number): void;

  /** 클라이언트를 방에서 내보낸다(room leave). */
  abstract leave(client: Socket, roomId: number): void;

  /** 현재 방에 접속한 소켓 수(presence). */
  abstract roomSize(roomId: number): Promise<number>;
}
