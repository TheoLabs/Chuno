import { RunnerStatsService } from './runner-stats.service';
import { RunnerStats, RunnerTier } from '@modules/scoring/domain/runner-stats.entity';
import { RaceStatus } from '@modules/race/domain/race.entity';
import { RunnerStatus } from '@modules/race/domain/race-participant.entity';

/**
 * S4-3 — RunnerStats 누적(RaceFinished 소비) 서비스 검증. 유저별 누적·티어·멱등(마커).
 */
describe('RunnerStatsService (S4-3)', () => {
  const t0 = new Date('2026-07-07T00:00:00.000Z');
  const finishedAt = new Date(t0.getTime() + 900_000);

  const makeRace = () => ({
    id: 42,
    status: RaceStatus.FINISHED,
    startedAt: t0,
    goal: { targetDistance: 5, limitMinutes: 30 },
    runners: [
      { userId: 1, status: RunnerStatus.FINISHED, distanceKm: 5, finishedAt }, // 1등
      { userId: 2, status: RunnerStatus.DNF, distanceKm: 2.5, finishedAt: null }, // 미완주
    ],
  });

  const setup = (opts?: { applied?: number; existing?: (userId: number) => RunnerStats | null }) => {
    const raceRepository = { find: jest.fn().mockResolvedValue([makeRace()]) };
    const runnerStatsRepository = {
      findOne: jest.fn().mockImplementation(({ userId }) => (opts?.existing ? opts.existing(userId) : null)),
      save: jest.fn().mockResolvedValue(undefined),
    };
    const appliedRepository = {
      count: jest.fn().mockResolvedValue(opts?.applied ?? 0),
      save: jest.fn().mockResolvedValue(undefined),
    };
    const service = new RunnerStatsService(raceRepository as never, runnerStatsRepository as never, appliedRepository as never);
    Object.assign(service, {
      context: { set: jest.fn(), get: jest.fn(() => []) },
      entityManager: { transaction: async (cb: (em: unknown) => unknown) => cb({}) },
      eventPublisher: { publish: jest.fn() },
    });
    return { service, runnerStatsRepository, appliedRepository };
  };

  it('유저별 누적 + 1등 winCount + 마커 저장', async () => {
    const { service, runnerStatsRepository, appliedRepository } = setup();
    await service.accumulate(100);

    const saved: RunnerStats[] = runnerStatsRepository.save.mock.calls[0][0];
    const byUser = Object.fromEntries(saved.map((s) => [s.userId, s]));
    // 1등(userId 1): raceCount 1, winCount 1, 점수>0.
    expect(byUser[1]).toMatchObject({ raceCount: 1, winCount: 1 });
    expect(byUser[1].totalScore).toBeGreaterThan(0);
    // 미완주(userId 2): raceCount 1, winCount 0.
    expect(byUser[2]).toMatchObject({ raceCount: 1, winCount: 0 });
    // 마커 저장(멱등 근거).
    expect(appliedRepository.save).toHaveBeenCalledTimes(1);
    expect(appliedRepository.save.mock.calls[0][0][0]).toMatchObject({ raceId: 42 });
  });

  it('기존 통계에 누적(합산)', async () => {
    const existing = (userId: number) => {
      const s = RunnerStats.create(userId);
      s.apply({ scoreTotal: 500, distanceKm: 5, isWin: true }); // 이전 1경기
      return s;
    };
    const { service, runnerStatsRepository } = setup({ existing });
    await service.accumulate(100);

    const saved: RunnerStats[] = runnerStatsRepository.save.mock.calls[0][0];
    const user1 = saved.find((s) => s.userId === 1)!;
    expect(user1.raceCount).toBe(2); // 1(이전) + 1
    expect(user1.winCount).toBe(2);
    expect(user1.totalScore).toBeGreaterThan(500);
  });

  it('이미 반영된 경주면 no-op(멱등 마커)', async () => {
    const { service, runnerStatsRepository, appliedRepository } = setup({ applied: 1 });
    await service.accumulate(100);
    expect(runnerStatsRepository.save).not.toHaveBeenCalled();
    expect(appliedRepository.save).not.toHaveBeenCalled();
  });

  it('티어는 누적 점수로 산출(브론즈 시작)', () => {
    const s = RunnerStats.create(1);
    expect(s.tier).toBe(RunnerTier.BRONZE);
    s.apply({ scoreTotal: 1200, distanceKm: 5, isWin: false }); // ≥1000 → 실버
    expect(s.tier).toBe(RunnerTier.SILVER);
  });
});
