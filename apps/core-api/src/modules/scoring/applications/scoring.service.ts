import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { Injectable, Logger } from '@nestjs/common';
import { RaceRepository } from '@modules/race/infrastructure/race.repository';
import { RaceStatus } from '@modules/race/domain/race.entity';
import { RaceResult } from '@modules/scoring/domain/race-result.entity';
import { RaceResultRepository } from '@modules/scoring/infrastructure/race-result.repository';
import { computeRaceResults } from '@modules/scoring/domain/scoring';
import { toScoringInputs } from './race-to-inputs';

/**
 * 결과 산출 서비스 (S4-2) — RaceFinished 소비 시 러너별 순위·점수를 산출해 RaceResult N건 저장.
 *
 * 멱등: (raceId,userId) 유니크 + 저장 전 raceId 존재 카운트로 중복 이벤트에 no-op.
 * RaceFinished payload가 roomId만 담으므로 raceId로 못 찾고 roomId로 Race(runners)를 로드해 계산한다.
 */
@Injectable()
export class ScoringService extends DddService {
  private readonly logger = new Logger(ScoringService.name);

  constructor(
    private readonly raceRepository: RaceRepository,
    private readonly raceResultRepository: RaceResultRepository
  ) {
    super();
  }

  /** 종료된 방(roomId)의 경주 결과를 산출·저장. 멱등. */
  @Transactional()
  async recordResults(roomId: number): Promise<void> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    if (!race) return; // 롤백/삭제된 경주 — no-op
    if (race.status !== RaceStatus.FINISHED) return; // 종료 확정 후에만 집계

    const already = await this.raceResultRepository.count({ raceId: race.id });
    if (already > 0) return; // 이미 저장됨 — 멱등(중복 RaceFinished 방어)

    const { goal, runners } = toScoringInputs(race);
    const results = computeRaceResults(goal, runners);
    const entities = results.map((result) => RaceResult.of({ raceId: race.id, result }));

    await this.raceResultRepository.save(entities);
    this.logger.log(`RaceResult ${entities.length}건 저장(raceId=${race.id}, roomId=${roomId})`);
  }
}
