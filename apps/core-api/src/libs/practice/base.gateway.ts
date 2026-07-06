import { Logger } from '@nestjs/common';
import { OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit, WebSocketServer } from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { SocketIoBroadcaster } from './socketio-broadcaster';
import { WsAuthMiddleware } from './ws-auth.middleware';

/**
 * 실시간 게이트웨이 공통 뼈대(추상).
 *
 * 연결 수명주기·인증 미들웨어 등록·브로드캐스터 바인딩 같은 **횡단 관심사**만 담는다.
 * 방(room) 참여/입퇴장/상태전환 같은 **도메인 의미**는 하위 게이트웨이/구독자에 둔다
 * (게이트웨이는 얇게 유지).
 *
 * 하위 게이트웨이는 전송 옵션을 직접 선언하고 이 클래스를 extends 한다:
 *
 * ```ts
 * @UseInterceptors(WsContextInterceptor)
 * @WebSocketGateway({ namespace: '/lobby', cors: { origin: '*' } })
 * export class LobbyGateway extends BaseGateway {
 *   constructor(broadcaster: SocketIoBroadcaster, wsAuth: WsAuthMiddleware) {
 *     super(broadcaster, wsAuth);
 *   }
 *   // @SubscribeMessage(...) 로 도메인 메시지 처리
 * }
 * ```
 * (데코레이터는 상속되지 않으므로 `@WebSocketGateway`/`@UseInterceptors`는 각 게이트웨이가 선언.)
 */
export abstract class BaseGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  protected readonly logger = new Logger(this.constructor.name);

  @WebSocketServer()
  protected server!: Server;

  protected constructor(
    protected readonly broadcaster: SocketIoBroadcaster,
    protected readonly wsAuth: WsAuthMiddleware
  ) {}

  /** 게이트웨이 초기화 — 핸드셰이크 인증 미들웨어 등록 + 브로드캐스터에 io 서버 바인딩. */
  afterInit(server: Server): void {
    // server.use: 연결 수립 전 매 핸드셰이크마다 실행되는 미들웨어(인증 실패 시 연결 거절).
    server.use(this.wsAuth.middleware());
    this.broadcaster.bind(server);
    this.logger.log('WS gateway initialized');
  }

  handleConnection(client: Socket): void {
    // 핸드셰이크 미들웨어가 심은 전체 User(있으면). 로깅엔 식별자만 사용.
    const userId = (client.data?.user as { id?: number } | undefined)?.id;
    this.logger.debug(`WS connected: ${client.id} user=${userId ?? 'anon'}`);
  }

  handleDisconnect(client: Socket): void {
    this.logger.debug(`WS disconnected: ${client.id}`);
  }
}
