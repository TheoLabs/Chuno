import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { Context, ContextKey } from '@libs/context';
import { UserGuard } from '@libs/guards';
import { User } from '@modules/user/domain/user.entity';
import { RankingScope, RankingService } from '@modules/scoring/applications/ranking.service';
import { RankingQueryDto } from '@modules/scoring/presentation/dto';

/**
 * 랭킹 API (S4-5) — 인증 필요. `GET /rankings?scope=all|weekly|monthly`.
 * 내 순위 + 주변 순위(items)를 함께 반환. 목록 포맷 { data: { items, total } } + me.
 */
@Controller('rankings')
@UseGuards(UserGuard)
export class RankingController {
  constructor(
    private readonly rankingService: RankingService,
    private readonly context: Context
  ) {}

  @Get()
  async getRankings(@Query() query: RankingQueryDto) {
    const user = this.context.get<User>(ContextKey.USER);
    const scope = query.scope ?? RankingScope.ALL;

    const { items, total, me } = await this.rankingService.getRanking({ userId: user.id, scope });

    return { data: { items, total, me } };
  }
}
