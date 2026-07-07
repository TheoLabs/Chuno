import { Race, RaceStatus, RaceGoal } from './race.entity';
import { RunnerStatus } from './race-participant.entity';
import { RaceStarted, RunnerFinished, RaceFinished } from './events/race.events';

/**
 * S3-3~S3-6 — Race 애그리거트 순수 도메인 검증(목 없이).
 * 진행 클램프·안티치트 리젝(S3-5)·종료 판정/finalize 멱등(S3-6)·생성(S3-3).
 */
describe('Race 도메인', () => {
  const t0 = new Date('2026-07-07T00:00:00.000Z');
  const at = (sec: number): Date => new Date(t0.getTime() + sec * 1000);
  const goal: RaceGoal = { targetDistance: 5, limitMinutes: 30 };

  const makeRace = (userIds: number[] = [10, 20]): Race =>
    Race.create({ roomId: 1, goal, runnerUserIds: userIds, startedAt: t0 });

  const runnerOf = (race: Race, userId: number) => race.runners.find((r) => r.userId === userId)!;

  describe('생성 (S3-3)', () => {
    it('LIVE·전원 RUNNING·동일 startedAt·RaceStarted 발행', () => {
      const race = makeRace();
      expect(race.status).toBe(RaceStatus.LIVE);
      expect(race.runners).toHaveLength(2);
      expect(race.runners.every((r) => r.status === RunnerStatus.RUNNING)).toBe(true);
      expect(race.runners.every((r) => r.distanceKm === 0)).toBe(true);
      expect(race.runners.every((r) => r.lastReportAt.getTime() === t0.getTime())).toBe(true);

      const started = race.getPublishedEvents().find((e) => e instanceof RaceStarted) as RaceStarted;
      expect(started).toBeInstanceOf(RaceStarted);
      expect(started).toMatchObject({ roomId: 1, startedAt: t0.getTime(), targetDistance: 5, limitMinutes: 30 });
    });
  });

  describe('진행 보고 — 정상/클램프 (S3-5)', () => {
    it('실현가능 진행은 수락되어 거리 반영', () => {
      const race = makeRace();
      // 60초 경과, 24km/h 상한 → 최대 0.4km. 0.3km는 수락.
      const result = race.report({ userId: 10, distanceKm: 0.3, now: at(60) });
      expect(result).toEqual({ accepted: true, finished: false });
      expect(runnerOf(race, 10).distanceKm).toBeCloseTo(0.3);
      expect(runnerOf(race, 10).lastReportAt.getTime()).toBe(at(60).getTime());
    });

    it('목표거리 초과분은 상한 클램프 후 완주(RunnerFinished)', () => {
      const race = makeRace();
      // 충분한 시간(1000초, 최대 6.66km) 뒤 6km 보고 → 5km로 클램프·완주.
      const result = race.report({ userId: 10, distanceKm: 6, now: at(1000) });
      expect(result).toEqual({ accepted: true, finished: true });
      const runner = runnerOf(race, 10);
      expect(runner.distanceKm).toBe(5);
      expect(runner.status).toBe(RunnerStatus.FINISHED);
      expect(runner.finishedAt?.getTime()).toBe(at(1000).getTime());
      expect(race.getPublishedEvents().some((e) => e instanceof RunnerFinished)).toBe(true);
    });
  });

  describe('안티치트 리젝 (S3-5)', () => {
    it('역행(이전 거리 미만) 리젝 — 상태 불변', () => {
      const race = makeRace();
      race.report({ userId: 10, distanceKm: 0.3, now: at(60) });
      const result = race.report({ userId: 10, distanceKm: 0.2, now: at(120) });
      expect(result).toMatchObject({ accepted: false, reason: 'backward' });
      expect(runnerOf(race, 10).distanceKm).toBeCloseTo(0.3);
      expect(runnerOf(race, 10).lastReportAt.getTime()).toBe(at(60).getTime());
    });

    it('비현실 페이스(순간이동) 리젝 — 상태 불변', () => {
      const race = makeRace();
      // 60초에 2km(=120km/h) → 상한 0.4km 초과, 리젝.
      const result = race.report({ userId: 10, distanceKm: 2, now: at(60) });
      expect(result).toMatchObject({ accepted: false, reason: 'infeasible-pace' });
      expect(runnerOf(race, 10).distanceKm).toBe(0);
    });

    it('Δt≤0에 진행 delta>0면 리젝', () => {
      const race = makeRace();
      const result = race.report({ userId: 10, distanceKm: 0.1, now: t0 }); // Δt=0
      expect(result).toMatchObject({ accepted: false, reason: 'infeasible-pace' });
      expect(runnerOf(race, 10).distanceKm).toBe(0);
    });
  });

  describe('종료 판정 / finalize 멱등 (S3-6)', () => {
    it('전원 완주 시 자동 finalize(RaceFinished·endedAt·FINISHED)', () => {
      const race = makeRace([10, 20]);
      race.report({ userId: 10, distanceKm: 5, now: at(1000) });
      expect(race.status).toBe(RaceStatus.LIVE); // 아직 20 미완주
      race.report({ userId: 20, distanceKm: 5, now: at(1100) });

      expect(race.status).toBe(RaceStatus.FINISHED);
      expect(race.endedAt?.getTime()).toBe(at(1100).getTime());
      expect(race.runners.every((r) => r.status === RunnerStatus.FINISHED)).toBe(true);
      expect(race.getPublishedEvents().filter((e) => e instanceof RaceFinished)).toHaveLength(1);
    });

    it('제한시간 경과 finalize — 미완주자 DNF·RaceFinished', () => {
      const race = makeRace([10, 20]);
      race.report({ userId: 10, distanceKm: 5, now: at(1000) }); // 10 완주
      race.finalize(at(1800)); // 30분 경과 트리거

      expect(race.status).toBe(RaceStatus.FINISHED);
      expect(runnerOf(race, 10).status).toBe(RunnerStatus.FINISHED); // 완주자 불변
      expect(runnerOf(race, 20).status).toBe(RunnerStatus.DNF); // 미완주자 DNF
      expect(race.getPublishedEvents().filter((e) => e instanceof RaceFinished)).toHaveLength(1);
    });

    it('finalize 멱등 — 재호출해도 결과·이벤트 불변', () => {
      const race = makeRace([10, 20]);
      race.finalize(at(1800));
      const status = race.status;
      const endedAt = race.endedAt?.getTime();
      const finishedCount = race.getPublishedEvents().filter((e) => e instanceof RaceFinished).length;

      race.finalize(at(2000)); // 지연잡 재시작/중복 호출 시뮬

      expect(race.status).toBe(status);
      expect(race.endedAt?.getTime()).toBe(endedAt);
      expect(race.getPublishedEvents().filter((e) => e instanceof RaceFinished).length).toBe(finishedCount);
    });

    it('종료된 경주엔 진행 보고 리젝(not-running)', () => {
      const race = makeRace([10, 20]);
      race.finalize(at(1800));
      const result = race.report({ userId: 10, distanceKm: 1, now: at(1900) });
      expect(result).toMatchObject({ accepted: false, reason: 'not-running' });
    });
  });
});
