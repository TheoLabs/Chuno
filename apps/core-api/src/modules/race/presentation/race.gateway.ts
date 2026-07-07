import { Logger, OnModuleDestroy, UseInterceptors } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import type { Namespace, Socket } from 'socket.io';
import { ServerClock, WsAuthMiddleware, WsContextInterceptor } from '@libs/socket';
import { User } from '@modules/user/domain/user.entity';
import { RaceService } from '@modules/race/applications/race.service';
import { RaceStatus } from '@modules/race/domain/race.entity';
import { RaceBroadcaster } from './race-broadcaster';

/** 리더보드 주기 브로드캐스트 간격(ms) — 서버 권위 순위를 활성 경주 룸에 밀어준다(2~5초 범위). */
const LEADERBOARD_INTERVAL_MS = 3_000;

/**
 * 경주 실시간 게이트웨이 (S3-4) — 네임스페이스 '/race'.
 *
 * 핸드셰이크 JWT 인증(`WsAuthMiddleware` 재사용)을 이 네임스페이스에 등록해 미인증 소켓을 거부한다.
 * 클라는 `joinRoom`{roomId}으로 자기 경주 룸에 참여(해당 방 러너만), `progress`{roomId,distanceKm}로 거리 보고.
 * 서버는 좌표를 받지 않고 거리만 서버 권위로 집계하며, 주기 타이머로 리더보드를 브로드캐스트한다.
 * 완주/종료 브로드캐스트(runnerFinished/raceFinished)는 도메인 이벤트를 소비하는 `RaceBroadcastHandler`가 발신한다.
 */
@UseInterceptors(WsContextInterceptor)
@WebSocketGateway({ namespace: '/race', cors: { origin: '*' } })
export class RaceGateway implements OnGatewayInit, OnModuleDestroy {
  private readonly logger = new Logger(RaceGateway.name);
  /** 리더보드 주기 브로드캐스트 대상(활성 경주 룸). */
  private readonly activeRoomIds = new Set<number>();
  private timer?: NodeJS.Timeout;

  @WebSocketServer()
  private namespace: Namespace;

  constructor(
    private readonly wsAuth: WsAuthMiddleware,
    private readonly broadcaster: RaceBroadcaster,
    private readonly races: RaceService,
    private readonly clock: ServerClock
  ) {}

  afterInit(namespace: Namespace): void {
    // '/race' 네임스페이스에 핸드셰이크 인증 등록(실패 시 연결 거절) + 브로드캐스터 바인딩.
    namespace.use(this.wsAuth.middleware());
    this.broadcaster.bind(namespace);
    // 활성 경주 룸에 주기적으로 리더보드 발신.
    this.timer = setInterval(() => {
      void this.broadcastLeaderboards();
    }, LEADERBOARD_INTERVAL_MS);
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /** 경주 룸 참여 — 해당 방 러너만. 성공 시 출발시각·서버시각·현재 리더보드 반환(동시 출발 동기화). */
  @SubscribeMessage('joinRoom')
  async onJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: number }
  ): Promise<{ event: string; data: unknown }> {
    const user = client.data.user as User;
    const roomId = Number(body?.roomId);
    if (!roomId) {
      throw new WsException('roomId가 필요합니다.');
    }

    const allowed = await this.races.isRunner(roomId, user.id);
    if (!allowed) {
      throw new WsException('해당 경주의 러너가 아닙니다.');
    }

    this.broadcaster.join(client, roomId);
    this.activeRoomIds.add(roomId);

    const snapshot = await this.races.getLeaderboard(roomId);
    return { event: 'joined', data: { roomId, serverTime: this.clock.nowEpochMs(), race: snapshot } };
  }

  /** 진행 거리 보고 — 도메인이 안티치트·클램프 검증 후 반영. 결과(수락/리젝)를 보고자에게 회신. */
  @SubscribeMessage('progress')
  async onProgress(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { roomId: number; distanceKm: number }
  ): Promise<{ event: string; data: unknown }> {
    const user = client.data.user as User;
    const roomId = Number(body?.roomId);
    const distanceKm = Number(body?.distanceKm);
    if (!roomId || !Number.isFinite(distanceKm)) {
      throw new WsException('roomId와 distanceKm이 필요합니다.');
    }

    const result = await this.races.reportProgress({ roomId, userId: user.id, distanceKm });
    return { event: 'progressAck', data: { roomId, ...result } };
  }

  /** 경주 룸 이탈(화면 이탈 등). */
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

  /** 활성 경주 룸별 리더보드 브로드캐스트. 종료/부재 룸은 활성 집합에서 제거. */
  private async broadcastLeaderboards(): Promise<void> {
    for (const roomId of [...this.activeRoomIds]) {
      try {
        const snapshot = await this.races.getLeaderboard(roomId);
        if (!snapshot) {
          this.activeRoomIds.delete(roomId);
          continue;
        }
        this.broadcaster.toRoom(roomId, 'leaderboard', snapshot);
        if (snapshot.status === RaceStatus.FINISHED) {
          this.activeRoomIds.delete(roomId); // 종료된 경주는 주기 발신 중단(최종 스냅샷은 방금 발신됨)
        }
      } catch (error) {
        this.logger.error(`리더보드 브로드캐스트 실패 (room=${roomId}): ${(error as Error).message}`);
      }
    }
  }
}
