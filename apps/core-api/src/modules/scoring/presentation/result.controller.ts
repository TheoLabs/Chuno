import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { Context, ContextKey } from '@libs/context';
import { UserGuard } from '@libs/guards';
import { User } from '@modules/user/domain/user.entity';
import { RaceResultQueryService } from '@modules/scoring/applications/race-result-query.service';
import { MyResultsQueryDto } from '@modules/scoring/presentation/dto';

/**
 * 내 기록 API (S4-5) — 인증 필요. `GET /users/me/results`(내 RaceResult 목록, 페이지네이션).
 * 목록 포맷 { data: { items, total } }.
 */
@Controller('users')
@UseGuards(UserGuard)
export class MyResultController {
  constructor(
    private readonly resultQueryService: RaceResultQueryService,
    private readonly context: Context
  ) {}

  @Get('me/results')
  async getMyResults(@Query() query: MyResultsQueryDto) {
    const user = this.context.get<User>(ContextKey.USER);
    const data = await this.resultQueryService.getMyResults(user.id, query);
    return { data };
  }
}

/**
 * 경주 결과 API (S4-5) — 인증 필요. `GET /races/:id/result`(그 경주 전체 결과, 러너 전원).
 * 단건 포맷 { data: { ... } }.
 */
@Controller('races')
@UseGuards(UserGuard)
export class RaceResultController {
  constructor(private readonly resultQueryService: RaceResultQueryService) {}

  @Get(':id/result')
  async getRaceResult(@Param('id', ParseIntPipe) id: number) {
    const data = await this.resultQueryService.getRaceResult(id);
    return { data };
  }
}
