import { Module } from '@nestjs/common';
import { RaceModule } from '@modules/race/race.module';
import { RaceResultRepository } from '@modules/scoring/infrastructure/race-result.repository';
import { RunnerStatsRepository } from '@modules/scoring/infrastructure/runner-stats.repository';
import { RaceStatAppliedRepository } from '@modules/scoring/infrastructure/race-stat-applied.repository';
import { ScoringService } from '@modules/scoring/applications/scoring.service';
import { RunnerStatsService } from '@modules/scoring/applications/runner-stats.service';
import { RankingService } from '@modules/scoring/applications/ranking.service';
import { RaceResultQueryService } from '@modules/scoring/applications/race-result-query.service';
import { ScoringResultHandler } from '@modules/scoring/presentation/scoring-result.handler';
import { RunnerStatsHandler } from '@modules/scoring/presentation/runner-stats.handler';
import { RankingController } from '@modules/scoring/presentation/ranking.controller';
import { MyResultController, RaceResultController } from '@modules/scoring/presentation/result.controller';

/**
 * 점수·랭킹 모듈 (S4-1~S4-5).
 *
 * - RaceModule import → RaceRepository로 종료된 Race(runners)를 로드해 결과·통계 산출.
 * - 도메인 이벤트 소비는 팬아웃 핸들러(ScoringResultHandler·RunnerStatsHandler)로 — 둘 다 RaceFinished에 반응.
 *   domain-events 큐 워커는 DomainEventsModule 디스패처가 소유하므로 여기서 큐를 등록하지 않는다.
 * - 조회 API(rankings·results)는 UserGuard(전역 JwtModule) 뒤에서 인증.
 */
@Module({
  imports: [RaceModule],
  controllers: [RankingController, MyResultController, RaceResultController],
  providers: [
    RaceResultRepository,
    RunnerStatsRepository,
    RaceStatAppliedRepository,
    ScoringService,
    RunnerStatsService,
    RankingService,
    RaceResultQueryService,
    ScoringResultHandler,
    RunnerStatsHandler,
  ],
  exports: [RaceResultRepository, RunnerStatsRepository],
})
export class ScoringModule {}
