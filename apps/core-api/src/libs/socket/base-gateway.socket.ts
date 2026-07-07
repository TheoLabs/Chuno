import { OnGatewayInit, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { WsAuthMiddleware } from './ws-auth.middleware';
import { SocketIoBroadcaster } from './socketio-broadcaster';

export abstract class BaseGateway implements OnGatewayInit {
  private readonly logger = new Logger(this.constructor.name);

  protected constructor(
    protected readonly wsAuth: WsAuthMiddleware,
    protected readonly broadcaster: SocketIoBroadcaster
  ) {}

  @WebSocketServer()
  protected server: Server;

  afterInit(server: Server) {
    // server.use: 연결 수립 전 매 핸드셰이크마다 실행되는 인증 미들웨어(실패 시 연결 거절).
    server.use(this.wsAuth.middleware());
    // 브로드캐스터에 io 서버를 바인딩 — 포트를 주입받는 소비자가 이 서버로 emit 하게 된다.
    this.broadcaster.bind(server);
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
