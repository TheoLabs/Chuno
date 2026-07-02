import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigsService } from '@configs';

export type AuthedUser = { userId: number };

type GuardRequest = {
  headers: Record<string, string | string[] | undefined>;
  user?: AuthedUser;
};

/**
 * 액세스 JWT(Bearer) 검증 가드. 성공 시 `req.user = { userId }`를 주입한다.
 * S1-6(users/me) 등 인증이 필요한 라우트에서 재사용한다(AuthModule이 export).
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly configs: ConfigsService
  ) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<GuardRequest>();
    const rawHeader = req.headers['authorization'];
    const header = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;

    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('액세스 토큰이 필요합니다.');
    }

    const token = header.slice('Bearer '.length);

    try {
      const payload = this.jwt.verify<{ sub: number }>(token, { secret: this.configs.jwt.accessSecret });
      req.user = { userId: Number(payload.sub) };
      return true;
    } catch {
      throw new UnauthorizedException('유효하지 않은 액세스 토큰입니다.');
    }
  }
}
