import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable } from 'rxjs';
import type { Socket } from 'socket.io';
import { asyncLocalStorage, ContextKey } from '@libs/context';

/**
 * WS 메시지 핸들러를 ALS 컨텍스트 스토어 안에서 실행한다 — HTTP의 `ContextMiddleware` 대응.
 *
 * 핸드셰이크에서 인증돼 `socket.data.user`에 실린 사용자를 `ContextKey.USER`로 심어,
 * 하위 서비스가 **전송 방식과 무관하게** `context.get<User>(USER)`로 현재 유저를 참조하게 한다.
 *
 * NOTE: `WsAuthMiddleware`(UserGuard 방식)가 핸드셰이크 때 전체 `User` 엔티티를 `socket.data.user`에
 * 실어 두므로, 여기서는 그걸 그대로 컨텍스트로 옮기기만 한다(HTTP `UserGuard`와 동일 의미).
 * 이 User는 연결 수립 시점 스냅샷이라, 최신값이 필요하면 핸들러/서비스에서 재조회한다.
 *
 * 사용: 게이트웨이 클래스에 `@UseInterceptors(WsContextInterceptor)`를 붙인다
 * (데코레이터는 상속되지 않으므로 각 게이트웨이가 직접 선언).
 */
@Injectable()
export class WsContextInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const client = ctx.switchToWs().getClient<Socket>();
    const store = new Map<string, unknown>();

    const user = client.data?.user;
    if (user) {
      store.set(ContextKey.USER, user);
    }

    // run 안에서 next.handle() 구독이 동기적으로 시작되므로 ALS 컨텍스트가 하위 체인에 전파된다.
    return asyncLocalStorage.run(store, () => next.handle());
  }
}
