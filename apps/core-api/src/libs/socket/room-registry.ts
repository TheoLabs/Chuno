import type { Server, Socket } from 'socket.io';

/**
 * 방 룸(room) 네이밍 규칙 — 애플리케이션의 방 id를 socket.io의 room 문자열로 매핑한다.
 *
 * socket.io의 "room"은 서버가 임의로 만드는 논리적 그룹으로, 같은 room에 join한
 * 소켓들에게만 `server.to(room).emit(...)`으로 브로드캐스트할 수 있다.
 * 여기서 방 id → `room:{id}` 로 규칙을 **한 곳(단일 진실 소스)** 에 둔다.
 */
export const roomKey = (roomId: number): string => `room:${roomId}`;

/**
 * 소켓 room 참여/이탈/인원(presence) 헬퍼.
 *
 * 순수 유틸(Nest provider 아님) — Broadcaster가 위임해 사용한다.
 * join/leave는 개별 소켓 기준, size는 io 서버 기준(멀티 인스턴스에선 어댑터가 집계)이다.
 */
export const RoomRegistry = {
  /** 이 소켓을 방 room에 join 시킨다. */
  join(client: Socket, roomId: number): void {
    client.join(roomKey(roomId));
  },

  /** 이 소켓을 방 room에서 leave 시킨다. */
  leave(client: Socket, roomId: number): void {
    client.leave(roomKey(roomId));
  },

  /** 방 room에 현재 접속한 소켓 수. (Redis 어댑터 사용 시 인스턴스 전체 집계) */
  async size(server: Server, roomId: number): Promise<number> {
    const sockets = await server.in(roomKey(roomId)).fetchSockets();
    return sockets.length;
  },
};
