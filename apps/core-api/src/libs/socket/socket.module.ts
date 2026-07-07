import { Global, Module } from '@nestjs/common';
import { RealtimeBroadcaster } from './realtime-broadcaster';
import { SocketIoBroadcaster } from './socketio-broadcaster';
import { WsAuthMiddleware } from './ws-auth.middleware';
import { WsContextInterceptor } from './ws-context.interceptor';
import { ServerClock } from './server-clock';

/**
 * 실시간(socket.io) 공통 인프라 — 전역 모듈.
 *
 * 전송·인증·컨텍스트·발행 포트·서버시계를 한데 묶어, 어느 도메인 모듈이든 주입해 쓰게 한다.
 * 도메인/애플리케이션 레이어는 구현(SocketIoBroadcaster)이 아니라 **포트(RealtimeBroadcaster)** 에
 * 의존해야 한다(테스트 목 주입·구현 교체 용이).
 *
 * - `RealtimeBroadcaster`(포트) → `SocketIoBroadcaster`(구현)에 `useExisting`으로 **같은 인스턴스** 바인딩:
 *   게이트웨이가 afterInit에서 io 서버를 bind한 그 인스턴스를, 포트를 주입받는 소비자도 공유해야 하기 때문.
 * - `JwtService`는 AuthModule의 `JwtModule({ global: true })`에서 전역 제공되므로 별도 import 불필요.
 */
@Global()
@Module({
  providers: [
    SocketIoBroadcaster,
    { provide: RealtimeBroadcaster, useExisting: SocketIoBroadcaster },
    WsAuthMiddleware,
    WsContextInterceptor,
    ServerClock,
  ],
  exports: [RealtimeBroadcaster, SocketIoBroadcaster, WsAuthMiddleware, WsContextInterceptor, ServerClock],
})
export class SocketModule {}
