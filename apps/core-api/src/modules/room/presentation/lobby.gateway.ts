import { UseInterceptors } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WsException,
} from '@nestjs/websockets';
import type { Socket } from 'socket.io';
import {
  BaseGateway,
  ServerClock,
  SocketIoBroadcaster,
  WsAuthMiddleware,
  WsContextInterceptor,
} from '@libs/socket';
import { User } from '@modules/user/domain/user.entity';
import { GeneralRoomService } from '@modules/room/applications/general-room.service';

/**
 * 로비 실시간 게이트웨이 (S2-4).
 *
 * 핸드셰이크 JWT 인증(미인증 소켓 거부)은 `BaseGateway`가 등록하는 `WsAuthMiddleware`가 담당한다.
 * (제재 게이팅 BO2-4는 이 핸드셰이크 훅에 크로스컷으로 추가될 지점.)
 *
 * 클라이언트는 방 상세 화면에서 `joinRoom`으로 해당 방 소켓 룸에 참여하고, 서버시각을 받아 카운트다운 오프셋(S2-9)을 맞춘다.
 * 입퇴장·상태전환·취소 브로드캐스트는 도메인 이벤트를 구독하는 `LobbyBroadcastProcessor`가 발신한다.
 *
 * NOTE(네임스페이스): MVP는 기본 네임스페이스('/')를 쓴다 — 브로드캐스터가 루트 io 서버를 그대로 쓰면 되기 때문.
 * S3-4('/race')에서 네임스페이스 분리가 필요하면 브로드캐스터를 네임스페이스 인지형으로 확장한다.
 */
@UseInterceptors(WsContextInterceptor)
@WebSocketGateway({ cors: { origin: '*' } })
export class LobbyGateway extends BaseGateway {
  constructor(
    wsAuth: WsAuthMiddleware,
    broadcaster: SocketIoBroadcaster,
    private readonly rooms: GeneralRoomService,
    private readonly clock: ServerClock
  ) {
    super(wsAuth, broadcaster);
  }

  /** 방 소켓 룸 참여 — 해당 방 Participant만 허용. 성공 시 서버시각을 함께 반환(오프셋 보정용). */
  @SubscribeMessage('joinRoom')
  async onJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: number }
  ): Promise<{ event: string; data: { roomId: number; serverTime: number } }> {
    const user = client.data.user as User;
    const roomId = Number(body?.roomId);
    if (!roomId) {
      throw new WsException('roomId가 필요합니다.');
    }

    const allowed = await this.rooms.isParticipant(roomId, user.id);
    if (!allowed) {
      throw new WsException('해당 방의 참가자가 아닙니다.');
    }

    this.broadcaster.join(client, roomId);
    return { event: 'joined', data: { roomId, serverTime: this.clock.nowEpochMs() } };
  }

  /** 방 소켓 룸 이탈(화면 이탈 등). 도메인상 방 나가기(참가 취소)는 REST(DELETE)로 별도 처리. */
  @SubscribeMessage('leaveRoom')
  onLeaveRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: number }
  ): { event: string; data: { roomId: number } } {
    const roomId = Number(body?.roomId);
    if (roomId) {
      this.broadcaster.leave(client, roomId);
    }
    return { event: 'left', data: { roomId } };
  }

  /** 서버 권위 시각(epoch millis) — 클라 카운트다운 오프셋 재동기용(S2-9). */
  @SubscribeMessage('serverTime')
  onServerTime(): { event: string; data: { serverTime: number } } {
    return { event: 'serverTime', data: { serverTime: this.clock.nowEpochMs() } };
  }
}
