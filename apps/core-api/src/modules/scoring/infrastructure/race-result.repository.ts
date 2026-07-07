import { DddRepository } from '@libs/ddd';
import { convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';
import { Injectable } from '@nestjs/common';
import { RaceResult } from '@modules/scoring/domain/race-result.entity';

export type WindowRow = { userId: number; score: number };

@Injectable()
export class RaceResultRepository extends DddRepository<RaceResult> {
  entityClass = RaceResult;

  async find(conditions: { raceId?: number; userId?: number }, options?: TypeormRelationOptions<RaceResult>) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({ raceId: conditions.raceId, userId: conditions.userId }),
      ...convertOptions(options),
    });
  }

  async count(conditions: { raceId?: number; userId?: number }) {
    return this.entityManager.count(this.entityClass, {
      where: stripUndefined({ raceId: conditions.raceId, userId: conditions.userId }),
    });
  }

  /**
   * 기간 윈도우(주간/월간) 유저별 점수 합산 랭킹 슬라이스 (S4-4).
   * createdAt ≥ since(롤링 윈도우, Season 테이블 없이 SQL 집계). total 합 내림차순.
   */
  async sumScoresByUser({ since, skip, take }: { since: Date; skip: number; take: number }): Promise<WindowRow[]> {
    const rows = await this.createQueryBuilder('r')
      .select('r.userId', 'userId')
      .addSelect('SUM(r.total)', 'score')
      .where('r.createdAt >= :since', { since })
      .groupBy('r.userId')
      .orderBy('score', 'DESC')
      .offset(skip)
      .limit(take)
      .getRawMany<{ userId: number; score: string }>();

    return rows.map((row) => ({ userId: Number(row.userId), score: Number(row.score) }));
  }

  /** 내 기간 점수 합(윈도우 내 total 합, 없으면 0). */
  async sumScoreForUser({ since, userId }: { since: Date; userId: number }): Promise<number> {
    const row = await this.createQueryBuilder('r')
      .select('SUM(r.total)', 'score')
      .where('r.createdAt >= :since', { since })
      .andWhere('r.userId = :userId', { userId })
      .getRawOne<{ score: string | null }>();

    return Number(row?.score ?? 0);
  }

  /** 내 점수보다 높은 유저 수(내 순위 = 이 값 + 1). 동점은 앞 순위로 안 세어 공동순위 처리. */
  async countUsersAbove({ since, score }: { since: Date; score: number }): Promise<number> {
    const rows = await this.createQueryBuilder('r')
      .select('r.userId', 'userId')
      .where('r.createdAt >= :since', { since })
      .groupBy('r.userId')
      .having('SUM(r.total) > :score', { score })
      .getRawMany();

    return rows.length;
  }

  /** 윈도우 내 랭킹에 오른 총 유저 수. */
  async countUsers({ since }: { since: Date }): Promise<number> {
    const rows = await this.createQueryBuilder('r')
      .select('r.userId', 'userId')
      .where('r.createdAt >= :since', { since })
      .groupBy('r.userId')
      .getRawMany();

    return rows.length;
  }
}
