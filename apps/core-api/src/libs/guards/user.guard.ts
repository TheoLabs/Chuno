import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigsService } from '@configs';
import { Context, ContextKey } from '@libs/context';
import { DataSource } from 'typeorm';
import { User } from '@modules/user/domain/user.entity';
import { InjectDataSource } from '@nestjs/typeorm';

export type AuthedUser = { userId: number };

type GuardRequest = {
  headers: Record<string, string | string[] | undefined>;
  user?: AuthedUser;
};

/**
 * 액세스 JWT(Bearer) 검증 가드.
 *
 * 성공 시 조회한 현재 유저(`User`)를 요청 컨텍스트(`Context`, `ContextKey.USER`)에 심어,
 * 하위 서비스/컨트롤러가 현재 유저를 바로 참조할 수 있게 한다.
 * 인증이 필요한 라우트에서 재사용한다.
 *
 * 주의: `JwtService` 주입이 필요하므로, 이 가드를 쓰는 모듈은 `JwtModule` 을
 * 사용할 수 있어야 한다(전역 등록 또는 해당 모듈에서 import). `ConfigsService`·`Context` 는 전역.
 */
@Injectable()
export class UserGuard implements CanActivate {
  constructor(
    @InjectDataSource() private readonly datasource: DataSource,
    private readonly jwt: JwtService,
    private readonly configs: ConfigsService,
    private readonly context: Context
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<GuardRequest>();
    const rawHeader = req.headers['authorization'];
    const header = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;

    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('액세스 토큰이 필요합니다.');
    }

    const token = header.slice('Bearer '.length);

    let userId: number;
    try {
      const payload = this.jwt.verify<{ sub: number }>(token, { secret: this.configs.jwt.accessSecret });
      userId = Number(payload.sub);
    } catch {
      throw new UnauthorizedException('유효하지 않은 액세스 토큰입니다.');
    }

    // DB 조회는 try 밖에서 — DB 오류가 "유효하지 않은 토큰"으로 오탐되지 않게.
    const user = await this.datasource
      .getRepository(User)
      .findOne({ where: { id: userId }, relations: { consents: true } });
    if (!user) {
      throw new UnauthorizedException('유저를 찾을 수 없습니다.');
    }

    this.context.set(ContextKey.USER, user);
    return true;
  }
}
