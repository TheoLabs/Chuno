import { Injectable } from '@nestjs/common';
import dayjs from '@libs/date';
import { RunnerStatsRepository } from '@modules/scoring/infrastructure/runner-stats.repository';
import { RaceResultRepository } from '@modules/scoring/infrastructure/race-result.repository';

export enum RankingScope {
  ALL = 'all',
  WEEKLY = 'weekly',
  MONTHLY = 'monthly',
}

export type RankingEntry = {
  rank: number;
  userId: number;
  score: number;
};

export type RankingResult = {
  scope: RankingScope;
  items: RankingEntry[]; // 내 주변(위아래 N명) 슬라이스. 통계 없으면 상위 슬라이스.
  total: number; // 랭킹에 오른 총 유저 수
  me: RankingEntry | null; // 내 순위(참가 이력 없으면 null)
};

/** 내 주변으로 잡을 위/아래 인원(각 방향 N명). */
const NEIGHBORS = 3;

/**
 * 랭킹 서비스 (S4-4) — 전체/주간/월간. (S4-5 GET /rankings가 사용)
 *
 * - 전체(all): RunnerStats.totalScore 랭킹.
 * - 주간/월간(weekly/monthly): RaceResult.createdAt 롤링 윈도우(7일/30일) 유저별 total 합산 SQL 집계
 *   (명시적 Season 테이블 없이 단순화). 내 순위 + 주변 순위(위아래 N명)를 함께 반환.
 */
@Injectable()
export class RankingService {
  constructor(
    private readonly runnerStatsRepository: RunnerStatsRepository,
    private readonly raceResultRepository: RaceResultRepository
  ) {}

  async getRanking({ userId, scope }: { userId: number; scope: RankingScope }): Promise<RankingResult> {
    return scope === RankingScope.ALL ? this.getAllTimeRanking(userId) : this.getWindowRanking(userId, scope);
  }

  /** 전체 랭킹 — RunnerStats 기준. */
  private async getAllTimeRanking(userId: number): Promise<RankingResult> {
    const [myStats, total] = await Promise.all([
      this.runnerStatsRepository.findOne({ userId }),
      this.runnerStatsRepository.countAll(),
    ]);

    if (!myStats) {
      // 참가 이력 없음 — 상위 슬라이스만.
      const top = await this.runnerStatsRepository.findRange({ skip: 0, take: NEIGHBORS * 2 + 1 });
      return {
        scope: RankingScope.ALL,
        items: top.map((stats, index) => ({ rank: index + 1, userId: stats.userId, score: stats.totalScore })),
        total,
        me: null,
      };
    }

    const above = await this.runnerStatsRepository.countAbove({ score: myStats.totalScore });
    const myRank = above + 1;
    const skip = Math.max(0, myRank - 1 - NEIGHBORS);
    const window = await this.runnerStatsRepository.findRange({ skip, take: NEIGHBORS * 2 + 1 });

    return {
      scope: RankingScope.ALL,
      items: window.map((stats, index) => ({ rank: skip + index + 1, userId: stats.userId, score: stats.totalScore })),
      total,
      me: { rank: myRank, userId, score: myStats.totalScore },
    };
  }

  /** 주간/월간 랭킹 — RaceResult 롤링 윈도우 합산. */
  private async getWindowRanking(userId: number, scope: RankingScope): Promise<RankingResult> {
    const days = scope === RankingScope.WEEKLY ? 7 : 30;
    const since = dayjs().subtract(days, 'day').toDate();

    const [myScore, total] = await Promise.all([
      this.raceResultRepository.sumScoreForUser({ since, userId }),
      this.raceResultRepository.countUsers({ since }),
    ]);

    if (myScore <= 0) {
      // 윈도우 내 이력 없음 — 상위 슬라이스만.
      const top = await this.raceResultRepository.sumScoresByUser({ since, skip: 0, take: NEIGHBORS * 2 + 1 });
      return {
        scope,
        items: top.map((row, index) => ({ rank: index + 1, userId: row.userId, score: row.score })),
        total,
        me: null,
      };
    }

    const above = await this.raceResultRepository.countUsersAbove({ since, score: myScore });
    const myRank = above + 1;
    const skip = Math.max(0, myRank - 1 - NEIGHBORS);
    const window = await this.raceResultRepository.sumScoresByUser({ since, skip, take: NEIGHBORS * 2 + 1 });

    return {
      scope,
      items: window.map((row, index) => ({ rank: skip + index + 1, userId: row.userId, score: row.score })),
      total,
      me: { rank: myRank, userId, score: myScore },
    };
  }
}
