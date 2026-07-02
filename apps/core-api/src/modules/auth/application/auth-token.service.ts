import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes, randomUUID } from 'crypto';
import { ConfigsService } from '@configs';
import { CalendarDate } from '@libs/types';
import dayjs from '@libs/date';
import { RefreshToken } from '../domain/refresh-token.entity';
import { RefreshTokenRepository } from '../infrastructure/refresh-token.repository';

export type TokenPair = {
  accessToken: string;
  refreshToken: string;
};

@Injectable()
export class AuthTokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly configs: ConfigsService,
    private readonly refreshTokens: RefreshTokenRepository
  ) {}

  // 최초 로그인: 새 계열의 액세스+리프레시 발급.
  async issuePair(userId: number): Promise<TokenPair> {
    return this.issue(userId, randomUUID());
  }

  // 회전: 제시된 리프레시가 유효하면 새 쌍 발급. 재사용(이미 회전/폐기)이면 계열 전체 무효화 + 401.
  async rotate(presentedRefresh: string): Promise<TokenPair> {
    const token = await this.refreshTokens.findByHash(this.hash(presentedRefresh));
    if (!token) {
      throw new UnauthorizedException('유효하지 않은 리프레시 토큰입니다.');
    }

    // 재사용 감지: 이미 회전됐거나 폐기된 토큰이 다시 제시됨 → 탈취로 간주, 계열 전체 무효화.
    if (!token.isUsable) {
      await this.revokeFamily(token.familyId);
      throw new UnauthorizedException('리프레시 토큰 재사용이 감지되어 세션이 무효화되었습니다.');
    }

    if (this.isExpired(token.expiresOn)) {
      token.markRevoked();
      await this.refreshTokens.save([token]);
      throw new UnauthorizedException('만료된 리프레시 토큰입니다.');
    }

    token.markRotated();
    const { plain, entity } = this.buildRefresh(token.userId, token.familyId);
    await this.refreshTokens.save([token, entity]);

    return { accessToken: this.signAccess(token.userId), refreshToken: plain };
  }

  // 로그아웃: 제시된 리프레시의 계열 전체 폐기.
  async revokeByRefresh(presentedRefresh: string): Promise<void> {
    const token = await this.refreshTokens.findByHash(this.hash(presentedRefresh));
    if (token) {
      await this.revokeFamily(token.familyId);
    }
  }

  private async issue(userId: number, familyId: string): Promise<TokenPair> {
    const { plain, entity } = this.buildRefresh(userId, familyId);
    await this.refreshTokens.save([entity]);
    return { accessToken: this.signAccess(userId), refreshToken: plain };
  }

  private buildRefresh(userId: number, familyId: string): { plain: string; entity: RefreshToken } {
    const plain = randomBytes(32).toString('hex');
    const entity = RefreshToken.issue({
      userId,
      tokenHash: this.hash(plain),
      familyId,
      expiresOn: this.refreshExpiresOn(),
    });
    return { plain, entity };
  }

  private async revokeFamily(familyId: string): Promise<void> {
    const tokens = await this.refreshTokens.findByFamily(familyId);
    const alive = tokens.filter((t) => !t.revoked);
    if (alive.length === 0) return;
    alive.forEach((t) => t.markRevoked());
    await this.refreshTokens.save(alive);
  }

  private signAccess(userId: number): string {
    // JwtModule에 secret/expiresIn(15m 권장, JWT_ACCESS_EXPIRES_IN)이 설정돼 있다.
    return this.jwt.sign({ sub: userId });
  }

  private hash(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private refreshExpiresOn(): CalendarDate {
    return dayjs.tz().add(this.configs.jwt.refreshExpiresInDays, 'day').format('YYYY-MM-DD HH:mm:ss') as CalendarDate;
  }

  private isExpired(expiresOn: CalendarDate): boolean {
    return dayjs.tz(expiresOn).isBefore(dayjs.tz());
  }
}
