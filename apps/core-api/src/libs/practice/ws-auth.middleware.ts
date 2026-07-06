import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { ConfigsService } from '@configs';
import { User } from '@modules/user/domain/user.entity';
import type { Socket } from 'socket.io';

/**
 * socket.io 핸드셰이크 인증 미들웨어 — **UserGuard 방식**(전체 User 엔티티를 컨텍스트에 싣는다).
 *
 * `server.use(wsAuth.middleware())` 로 등록하면, **연결 수립 전에 1회** 실행된다.
 * 액세스 JWT를 검증하고, 성공 시 그 유저를 DB에서 조회해 `socket.data.user = User` 로 심는다.
 * 실패하면 연결을 거절한다. 이후 `WsContextInterceptor`가 이 User를 ALS 컨텍스트로 옮겨,
 * 하위 서비스가 HTTP `UserGuard`와 **동일하게** `context.get<User>(USER)`로 전체 User를 쓴다.
 *
 * 비용/일관성 트레이드오프:
 * - DB 조회는 **연결당 1회**(메시지당 아님) — HTTP처럼 매 요청 조회하지 않으므로 저렴하다.
 * - 대신 이 User는 **소켓 수명 동안 캐시**된다 → 도중 변경(닉네임·동의 등)엔 stale할 수 있다.
 *   항상 최신이 필요한 핸들러에서는 그 시점에 재조회한다.
 *
 * 레이어링: 모듈의 `UserRepository`가 아니라 `DataSource`를 주입한다(libs가 특정 module provider에
 * 결합하지 않도록 — HTTP `UserGuard`와 동일 전략). `User` 엔티티 참조만 공유한다.
 */
@Injectable()
export class WsAuthMiddleware {
  constructor(
    private readonly jwt: JwtService,
    private readonly configs: ConfigsService,
    @InjectDataSource() private readonly datasource: DataSource
  ) {}

  /** `server.use(...)`에 넘길 미들웨어 함수를 생성한다(핸드셰이크 시 async 검증·조회). */
  middleware() {
    return async (socket: Socket, next: (err?: Error) => void): Promise<void> => {
      const token = this.extractToken(socket);
      if (!token) {
        return next(new Error('액세스 토큰이 필요합니다.'));
      }

      let userId: number;
      try {
        const payload = this.jwt.verify<{ sub: number }>(token, { secret: this.configs.jwt.accessSecret });
        userId = Number(payload.sub);
      } catch {
        return next(new Error('유효하지 않은 액세스 토큰입니다.'));
      }

      // DB 조회는 검증(try) 밖에서 — DB 오류가 "유효하지 않은 토큰"으로 오탐되지 않게(UserGuard와 동일).
      const user = await this.datasource
        .getRepository(User)
        .findOne({ where: { id: userId }, relations: { consents: true } });
      if (!user) {
        return next(new Error('유저를 찾을 수 없습니다.'));
      }

      socket.data.user = user; // 전체 User 엔티티(HTTP UserGuard의 ContextKey.USER와 동일 의미)
      next();
    };
  }

  /** `handshake.auth.token`(Bearer 접두 허용) → Authorization 헤더 순으로 토큰을 추출. */
  private extractToken(socket: Socket): string | null {
    const fromAuth = socket.handshake.auth?.token as string | undefined;
    if (typeof fromAuth === 'string' && fromAuth.length > 0) {
      return fromAuth.startsWith('Bearer ') ? fromAuth.slice('Bearer '.length) : fromAuth;
    }
    const header = socket.handshake.headers?.authorization;
    if (typeof header === 'string' && header.startsWith('Bearer ')) {
      return header.slice('Bearer '.length);
    }
    return null;
  }
}
