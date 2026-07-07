import { ScoringService } from './scoring.service';
import { RaceStatus } from '@modules/race/domain/race.entity';
import { RunnerStatus } from '@modules/race/domain/race-participant.entity';

/**
 * S4-2 — RaceResult 저장(RaceFinished 소비) 서비스 검증. 참가자 수만큼 저장 + 멱등.
 */
describe('ScoringService (S4-2)', () => {
  const t0 = new Date('2026-07-07T00:00:00.000Z');
  const finishedAt = new Date(t0.getTime() + 900_000); // 900s

  const makeRace = () => ({
    id: 42,
    status: RaceStatus.FINISHED,
    startedAt: t0,
    goal: { targetDistance: 5, limitMinutes: 30 },
    runners: [
      { userId: 1, status: RunnerStatus.FINISHED, distanceKm: 5, finishedAt },
      { userId: 2, status: RunnerStatus.DNF, distanceKm: 2.5, finishedAt: null },
    ],
  });

  const setup = (raceOverride?: unknown) => {
    const raceRepository = { find: jest.fn().mockResolvedValue(raceOverride !== undefined ? raceOverride : [makeRace()]) };
    const raceResultRepository = { count: jest.fn().mockResolvedValue(0), save: jest.fn().mockResolvedValue(undefined) };
    const service = new ScoringService(raceRepository as never, raceResultRepository as never);
    // @Transactional 통과용 최소 컨텍스트 주입.
    Object.assign(service, {
      context: { set: jest.fn(), get: jest.fn(() => []) },
      entityManager: { transaction: async (cb: (em: unknown) => unknown) => cb({}) },
      eventPublisher: { publish: jest.fn() },
    });
    return { service, raceRepository, raceResultRepository };
  };

  it('종료 경주 → 참가자 수만큼 RaceResult 저장', async () => {
    const { service, raceResultRepository } = setup();
    await service.recordResults(100);

    expect(raceResultRepository.save).toHaveBeenCalledTimes(1);
    const saved = raceResultRepository.save.mock.calls[0][0];
    expect(saved).toHaveLength(2);
    expect(saved.every((r: { raceId: number }) => r.raceId === 42)).toBe(true);
    // 완주자(1등)와 미완주자 결과가 모두 저장.
    const byUser = Object.fromEntries(saved.map((r: { userId: number; rank: number; finished: boolean }) => [r.userId, r]));
    expect(byUser[1]).toMatchObject({ rank: 1, finished: true });
    expect(byUser[2]).toMatchObject({ rank: 2, finished: false });
  });

  it('이미 저장된 경주면 no-op(멱등)', async () => {
    const { service, raceResultRepository } = setup();
    raceResultRepository.count.mockResolvedValue(2); // 이미 존재
    await service.recordResults(100);
    expect(raceResultRepository.save).not.toHaveBeenCalled();
  });

  it('경주 없음/미종료면 no-op', async () => {
    const { service: s1, raceResultRepository: r1 } = setup([]); // 없음
    await s1.recordResults(100);
    expect(r1.save).not.toHaveBeenCalled();

    const { service: s2, raceResultRepository: r2 } = setup([{ ...makeRace(), status: RaceStatus.LIVE }]);
    await s2.recordResults(100);
    expect(r2.save).not.toHaveBeenCalled();
  });
});
