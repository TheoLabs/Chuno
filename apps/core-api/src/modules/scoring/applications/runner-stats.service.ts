import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { Injectable, Logger } from '@nestjs/common';
import { RaceRepository } from '@modules/race/infrastructure/race.repository';
import { RaceStatus } from '@modules/race/domain/race.entity';
import { RunnerStats } from '@modules/scoring/domain/runner-stats.entity';
import { RaceStatApplied } from '@modules/scoring/domain/race-stat-applied.entity';
import { RunnerStatsRepository } from '@modules/scoring/infrastructure/runner-stats.repository';
import { RaceStatAppliedRepository } from '@modules/scoring/infrastructure/race-stat-applied.repository';
import { computeRaceResults } from '@modules/scoring/domain/scoring';
import { toScoringInputs } from './race-to-inputs';

/**
 * 러너 통계 누적 서비스 (S4-3) — RaceFinished를 S4-2와 별개 트랜잭션으로 소비(디스패처가 핸들러별 ALS 격리).
 *
 * 유저별 RunnerStats(totalScore·totalDistanceKm·raceCount·winCount·tier)를 누적한다.
 * 멱등: 누적은 카운터라 유니크로 자연 멱등이 안 됨 → 같은 트랜잭션에 RaceStatApplied(raceId 유니크) 마커를 심어
 *      중복 반영을 차단(RaceResult 존재에 의존하지 않는 독립 마커라 S4-2와의 실행 순서에 안전).
 */
@Injectable()
export class RunnerStatsService extends DddService {
  private readonly logger = new Logger(RunnerStatsService.name);

  constructor(
    private readonly raceRepository: RaceRepository,
    private readonly runnerStatsRepository: RunnerStatsRepository,
    private readonly appliedRepository: RaceStatAppliedRepository
  ) {
    super();
  }

  /** 종료된 방(roomId)의 결과를 유저 통계에 누적. 멱등(마커). */
  @Transactional()
  async accumulate(roomId: number): Promise<void> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    if (!race) return;
    if (race.status !== RaceStatus.FINISHED) return;

    const already = await this.appliedRepository.count({ raceId: race.id });
    if (already > 0) return; // 이미 누적됨 — 멱등

    const { goal, runners } = toScoringInputs(race);
    const results = computeRaceResults(goal, runners);

    const statsToSave: RunnerStats[] = [];
    for (const result of results) {
      const stats = (await this.runnerStatsRepository.findOne({ userId: result.userId })) ?? RunnerStats.create(result.userId);
      stats.apply({ scoreTotal: result.score.total, distanceKm: result.distanceKm, isWin: result.rank === 1 });
      statsToSave.push(stats);
    }

    // 마커를 같은 트랜잭션에 심어 raceId 유니크로 중복 반영 차단.
    await this.runnerStatsRepository.save(statsToSave);
    await this.appliedRepository.save([RaceStatApplied.of(race.id)]);
    this.logger.log(`RunnerStats ${statsToSave.length}명 누적(raceId=${race.id}, roomId=${roomId})`);
  }
}
