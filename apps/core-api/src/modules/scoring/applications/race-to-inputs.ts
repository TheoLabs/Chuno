import { Race } from '@modules/race/domain/race.entity';
import { RunnerStatus } from '@modules/race/domain/race-participant.entity';
import { RunnerInput, ScoreGoal } from '@modules/scoring/domain/scoring';

/**
 * 종료된 Race를 스코어링 입력으로 변환 (S4-2/S4-3 공통).
 * finishTime = (finishedAt - startedAt) 초. 미완주자는 null. finished = 상태가 FINISHED.
 */
export function toScoringInputs(race: Race): { goal: ScoreGoal; runners: RunnerInput[] } {
  const startedMs = race.startedAt.getTime();
  const runners: RunnerInput[] = race.runners.map((runner) => ({
    userId: runner.userId,
    finished: runner.status === RunnerStatus.FINISHED,
    distanceKm: runner.distanceKm,
    finishTime: runner.finishedAt ? (runner.finishedAt.getTime() - startedMs) / 1000 : null,
  }));

  return { goal: race.goal, runners };
}
