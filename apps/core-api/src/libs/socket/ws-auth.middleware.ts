import { ConfigsService } from '@configs';
import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectDataSource } from '@nestjs/typeorm';
import { Socket } from 'socket.io';
import { DataSource } from 'typeorm';
import { User } from '@modules/user/domain/user.entity';

@Injectable()
export class WsAuthMiddleware {
  constructor(
    @InjectDataSource() private readonly datasource: DataSource,
    private readonly jwt: JwtService,
    private readonly configsService: ConfigsService
  ) {}

  middleware() {
    return (socket: Socket, next: (err?: Error) => void): void => {
      this.authenticate(socket)
        .then((user) => {
          socket.data.user = user; // 전체 User 엔티티(HTTP UserGuard의 USER와 동일 의미)
          next();
        })
        .catch((err: Error) => next(err));
    };
  }

  private async authenticate(socket: Socket): Promise<User> {
    const token = this.extractToken(socket);
    if (!token) {
      throw new Error('액세스 토큰이 필요합니다.');
    }

    let userId: number;
    try {
      const payload = this.jwt.verify<{ sub: number }>(token, { secret: this.configsService.jwt.accessSecret });
      userId = Number(payload.sub);
    } catch {
      throw new Error('유효하지 않은 액세스 토큰입니다.');
    }

    // 검증(try) 밖 — DB 오류가 "유효하지 않은 토큰"으로 오탐되지 않게. 이제 던져도 .catch가 next(err)로 처리.
    const user = await this.datasource
      .getRepository(User)
      .findOne({ where: { id: userId }, relations: { consents: true } });
    if (!user) {
      throw new Error('유저를 찾을 수 없습니다.');
    }
    return user;
  }

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
