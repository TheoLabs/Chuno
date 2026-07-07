import { DddRepository } from '@libs/ddd';
import { Injectable } from '@nestjs/common';
import { RaceStatApplied } from '@modules/scoring/domain/race-stat-applied.entity';

@Injectable()
export class RaceStatAppliedRepository extends DddRepository<RaceStatApplied> {
  entityClass = RaceStatApplied;

  async count(conditions: { raceId: number }): Promise<number> {
    return this.entityManager.count(this.entityClass, { where: { raceId: conditions.raceId } });
  }
}
