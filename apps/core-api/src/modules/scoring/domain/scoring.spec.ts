import { computeRaceResults, scoreRunner, rankRunners, SCORE_CAPS, RunnerInput, ScoreGoal } from './scoring';

/**
 * S4-1 — 스코어링 순수 계산 검증(목 없이). 4축(등수/거리/완주/여유)·미완주자·상한 클램프·결정성.
 */
describe('스코어링 (S4-1)', () => {
  const goal: ScoreGoal = { targetDistance: 5, limitMinutes: 30 }; // 제한 1800s

  describe('순위 산출', () => {
    it('완주자(finishTime 오름차순) 먼저, 그 뒤 미완주자(거리 내림차순)', () => {
      const runners: RunnerInput[] = [
        { userId: 1, finished: false, distanceKm: 2.5, finishTime: null },
        { userId: 2, finished: true, distanceKm: 5, finishTime: 1200 },
        { userId: 3, finished: true, distanceKm: 5, finishTime: 900 },
        { userId: 4, finished: false, distanceKm: 4, finishTime: null },
      ];
      const ranked = rankRunners(runners).map((r) => ({ userId: r.runner.userId, rank: r.rank }));
      expect(ranked).toEqual([
        { userId: 3, rank: 1 }, // 완주 900
        { userId: 2, rank: 2 }, // 완주 1200
        { userId: 4, rank: 3 }, // 미완주 4km
        { userId: 1, rank: 4 }, // 미완주 2.5km
      ]);
    });
  });

  describe('4축 배점', () => {
    it('완주 1등 — 등수 만점·거리 만점·완주보너스·여유', () => {
      // N=3, rank1 → rankScore 300; distance 5/5 → 200; finishBonus 220; margin (1800-900)/1800*100=50.
      const score = scoreRunner(goal, { userId: 1, finished: true, distanceKm: 5, finishTime: 900 }, 1, 3);
      expect(score).toEqual({ total: 770, rankScore: 300, distanceScore: 200, finishBonus: 220, marginScore: 50 });
    });

    it('완주 꼴찌 — 등수 0(하지만 거리·완주·여유는 유지)', () => {
      // N=3, rank3 → rankScore 0; margin (1800-1200)/1800*100=33.33→33.
      const score = scoreRunner(goal, { userId: 2, finished: true, distanceKm: 5, finishTime: 1200 }, 3, 3);
      expect(score).toMatchObject({ rankScore: 0, distanceScore: 200, finishBonus: 220, marginScore: 33 });
      expect(score.total).toBe(453);
    });

    it('미완주자 — 완주보너스 0·여유 0·거리 비례', () => {
      // distance 2.5/5 → 100; finishBonus 0; margin 0; rank(N=3, rank3) → 0.
      const score = scoreRunner(goal, { userId: 3, finished: false, distanceKm: 2.5, finishTime: null }, 3, 3);
      expect(score).toEqual({ total: 100, rankScore: 0, distanceScore: 100, finishBonus: 0, marginScore: 0 });
    });

    it('러너 1명이면 등수 만점', () => {
      const score = scoreRunner(goal, { userId: 1, finished: true, distanceKm: 5, finishTime: 900 }, 1, 1);
      expect(score.rankScore).toBe(SCORE_CAPS.rank);
    });
  });

  describe('상한 클램프', () => {
    it('거리 초과분은 만점으로 클램프(≤200)', () => {
      const score = scoreRunner(goal, { userId: 1, finished: true, distanceKm: 10, finishTime: 900 }, 1, 3);
      expect(score.distanceScore).toBe(SCORE_CAPS.distance);
    });

    it('제한시간 초과 완주는 여유 0으로 클램프', () => {
      const score = scoreRunner(goal, { userId: 1, finished: true, distanceKm: 5, finishTime: 2000 }, 1, 3);
      expect(score.marginScore).toBe(0);
    });

    it('total은 상한(1000) 이하', () => {
      const score = scoreRunner(goal, { userId: 1, finished: true, distanceKm: 5, finishTime: 0 }, 1, 2);
      expect(score.total).toBeLessThanOrEqual(SCORE_CAPS.total);
    });
  });

  describe('전체 산출·결정성', () => {
    const runners: RunnerInput[] = [
      { userId: 1, finished: true, distanceKm: 5, finishTime: 900 },
      { userId: 2, finished: true, distanceKm: 5, finishTime: 1200 },
      { userId: 3, finished: false, distanceKm: 2.5, finishTime: null },
    ];

    it('러너 전원 결과 + pointsAwarded 산출', () => {
      const results = computeRaceResults(goal, runners);
      expect(results.map((r) => ({ userId: r.userId, rank: r.rank, total: r.score.total, points: r.pointsAwarded }))).toEqual([
        { userId: 1, rank: 1, total: 770, points: 77 },
        { userId: 2, rank: 2, total: 603, points: 60 },
        { userId: 3, rank: 3, total: 100, points: 10 },
      ]);
    });

    it('같은 입력 → 같은 출력(결정성)', () => {
      expect(computeRaceResults(goal, runners)).toEqual(computeRaceResults(goal, runners));
    });
  });
});
