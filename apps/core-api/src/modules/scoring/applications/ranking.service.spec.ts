import { RankingService, RankingScope } from './ranking.service';

/**
 * S4-4 — 랭킹 기간 집계 검증. 전체(RunnerStats)·주간/월간(RaceResult 윈도우 합산)·내 순위+주변.
 */
describe('RankingService (S4-4)', () => {
  const setup = () => {
    const runnerStatsRepository = {
      findOne: jest.fn(),
      countAll: jest.fn(),
      countAbove: jest.fn(),
      findRange: jest.fn(),
    };
    const raceResultRepository = {
      sumScoreForUser: jest.fn(),
      countUsers: jest.fn(),
      countUsersAbove: jest.fn(),
      sumScoresByUser: jest.fn(),
    };
    const service = new RankingService(runnerStatsRepository as never, raceResultRepository as never);
    return { service, runnerStatsRepository, raceResultRepository };
  };

  describe('전체(all) — RunnerStats', () => {
    it('내 순위 = 나보다 높은 유저 수 + 1, 주변 슬라이스 rank 연속', () => {
      const { service, runnerStatsRepository } = setup();
      runnerStatsRepository.findOne.mockResolvedValue({ userId: 7, totalScore: 500 });
      runnerStatsRepository.countAll.mockResolvedValue(10);
      runnerStatsRepository.countAbove.mockResolvedValue(3); // rank 4
      // skip = max(0, 4-1-3)=0, take 7.
      runnerStatsRepository.findRange.mockResolvedValue([
        { userId: 1, totalScore: 900 },
        { userId: 2, totalScore: 800 },
        { userId: 3, totalScore: 700 },
        { userId: 7, totalScore: 500 },
      ]);

      return service.getRanking({ userId: 7, scope: RankingScope.ALL }).then((res) => {
        expect(res.me).toEqual({ rank: 4, userId: 7, score: 500 });
        expect(res.total).toBe(10);
        expect(res.items[0]).toEqual({ rank: 1, userId: 1, score: 900 });
        expect(res.items[3]).toEqual({ rank: 4, userId: 7, score: 500 });
        expect(runnerStatsRepository.findRange).toHaveBeenCalledWith({ skip: 0, take: 7 });
      });
    });

    it('참가 이력 없으면 me=null, 상위 슬라이스', async () => {
      const { service, runnerStatsRepository } = setup();
      runnerStatsRepository.findOne.mockResolvedValue(null);
      runnerStatsRepository.countAll.mockResolvedValue(2);
      runnerStatsRepository.findRange.mockResolvedValue([{ userId: 1, totalScore: 300 }]);

      const res = await service.getRanking({ userId: 99, scope: RankingScope.ALL });
      expect(res.me).toBeNull();
      expect(res.items).toEqual([{ rank: 1, userId: 1, score: 300 }]);
    });
  });

  describe('주간/월간 — RaceResult 윈도우 합산', () => {
    it('윈도우 합산으로 내 순위·주변 산출', async () => {
      const { service, raceResultRepository } = setup();
      raceResultRepository.sumScoreForUser.mockResolvedValue(300);
      raceResultRepository.countUsers.mockResolvedValue(5);
      raceResultRepository.countUsersAbove.mockResolvedValue(2); // rank 3
      raceResultRepository.sumScoresByUser.mockResolvedValue([
        { userId: 1, score: 800 },
        { userId: 2, score: 500 },
        { userId: 7, score: 300 },
      ]);

      const res = await service.getRanking({ userId: 7, scope: RankingScope.WEEKLY });
      expect(res.scope).toBe(RankingScope.WEEKLY);
      expect(res.me).toEqual({ rank: 3, userId: 7, score: 300 });
      expect(res.total).toBe(5);
      expect(res.items.map((i) => i.rank)).toEqual([1, 2, 3]);
      // 주간 = 최근 7일 윈도우(since가 과거 시각으로 전달됨).
      const sinceArg = raceResultRepository.sumScoreForUser.mock.calls[0][0].since as Date;
      expect(sinceArg.getTime()).toBeLessThan(Date.now());
    });

    it('윈도우 내 이력 없으면 me=null, 상위 슬라이스', async () => {
      const { service, raceResultRepository } = setup();
      raceResultRepository.sumScoreForUser.mockResolvedValue(0);
      raceResultRepository.countUsers.mockResolvedValue(1);
      raceResultRepository.sumScoresByUser.mockResolvedValue([{ userId: 1, score: 200 }]);

      const res = await service.getRanking({ userId: 99, scope: RankingScope.MONTHLY });
      expect(res.me).toBeNull();
      expect(res.items).toEqual([{ rank: 1, userId: 1, score: 200 }]);
    });
  });
});
