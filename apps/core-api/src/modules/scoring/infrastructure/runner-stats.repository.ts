import { DddRepository } from '@libs/ddd';
import { stripUndefined } from '@libs/utils';
import { Injectable } from '@nestjs/common';
import { RunnerStats } from '@modules/scoring/domain/runner-stats.entity';

@Injectable()
export class RunnerStatsRepository extends DddRepository<RunnerStats> {
  entityClass = RunnerStats;

  async findOne(conditions: { userId: number }): Promise<RunnerStats | null> {
    return this.entityManager.findOne(this.entityClass, {
      where: stripUndefined({ userId: conditions.userId }),
    });
  }

  /** 전체 랭킹 슬라이스 (S4-4, scope=all) — totalScore 내림차순. */
  async findRange({ skip, take }: { skip: number; take: number }): Promise<RunnerStats[]> {
    return this.entityManager.find(this.entityClass, {
      order: { totalScore: 'DESC' },
      skip,
      take,
    });
  }

  /** 내 점수보다 높은 유저 수(내 순위 = 이 값 + 1). 동점 공동순위. */
  async countAbove({ score }: { score: number }): Promise<number> {
    return this.createQueryBuilder('s').where('s.totalScore > :score', { score }).getCount();
  }

  /** 전체 랭킹 유저 수. */
  async countAll(): Promise<number> {
    return this.entityManager.count(this.entityClass);
  }
}
