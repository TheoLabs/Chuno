/**
 * 스코어링 (S4-1) — 서버 권위의 **순수 계산**. 같은 입력 → 같은 출력(부수효과·시각·랜덤 없음)이라 유닛테스트가 쉽다.
 *
 * 4축 배점(MVP 초안 — 근거는 각 함수 주석):
 *   - rankScore   ≤ 300 : 등수(1등이 최고, 꼴찌가 0). 상대 경쟁 반영.
 *   - distanceScore ≤ 200 : 목표거리 대비 달성률. 완주자는 만점, 미완주자는 비례.
 *   - finishBonus  = 220 or 0 : 완주 성공 보너스(단일 결정적 값). 미완주자 0.
 *   - marginScore  ≤ 100 : 제한시간 대비 "여유"(빨리 끝낼수록 높음). 미완주자 0.
 *   - total = rankScore + distanceScore + finishBonus + marginScore, ≤ 1000 클램프.
 *     (이론상 최대 300+200+220+100=820이라 상한엔 여유가 있으나 방어적으로 클램프.)
 *
 * 순위 산출 규칙(입력에 rank 없음 — 여기서 계산):
 *   완주자 = finishTime(초) 오름차순(먼저 끝낸 사람이 앞), 그 뒤에 미완주자 = distanceKm 내림차순.
 */

export type ScoreGoal = {
  targetDistance: number; // km
  limitMinutes: number;
};

/** 스코어링 입력(러너 1명). finishTime은 완주자만(초, startedAt~finishedAt), 미완주자는 null. */
export type RunnerInput = {
  userId: number;
  finished: boolean;
  distanceKm: number;
  finishTime: number | null; // seconds
};

/** 점수 VO — 4축 + 합계. RaceResult에 컬럼으로 저장된다. */
export type Score = {
  total: number;
  rankScore: number;
  distanceScore: number;
  finishBonus: number;
  marginScore: number;
};

export type RunnerResult = {
  userId: number;
  finished: boolean;
  distanceKm: number;
  finishTime: number | null;
  rank: number;
  score: Score;
  pointsAwarded: number;
};

/** 4축 상한(서버 권위). total은 방어적 상한. */
export const SCORE_CAPS = {
  rank: 300,
  distance: 200,
  finishBonus: 220,
  margin: 100,
  total: 1000,
} as const;

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

/**
 * 순위 산출 — 완주자(finishTime 오름차순) 먼저, 그 뒤 미완주자(distanceKm 내림차순).
 * finishTime 동률/거리 동률은 입력 순서를 안정적으로 유지(stable). rank는 1부터.
 */
export function rankRunners(runners: RunnerInput[]): { runner: RunnerInput; rank: number }[] {
  const ordered = runners
    .map((runner, index) => ({ runner, index }))
    .sort((a, b) => {
      const af = a.runner.finished;
      const bf = b.runner.finished;
      if (af !== bf) return af ? -1 : 1; // 완주자 우선
      if (af && bf) {
        // 둘 다 완주 — finishTime 오름차순(null은 뒤로).
        const at = a.runner.finishTime ?? Number.POSITIVE_INFINITY;
        const bt = b.runner.finishTime ?? Number.POSITIVE_INFINITY;
        if (at !== bt) return at - bt;
      } else {
        // 둘 다 미완주 — distanceKm 내림차순.
        if (a.runner.distanceKm !== b.runner.distanceKm) return b.runner.distanceKm - a.runner.distanceKm;
      }
      return a.index - b.index; // 안정 정렬(동률 시 입력 순서 유지)
    });

  return ordered.map((entry, index) => ({ runner: entry.runner, rank: index + 1 }));
}

/**
 * 한 러너의 4축 점수 산출.
 * @param totalRunners 전체 러너 수(등수 정규화 분모).
 */
export function scoreRunner(goal: ScoreGoal, runner: RunnerInput, rank: number, totalRunners: number): Score {
  // 등수: 1등 = 만점, 꼴찌 = 0. 러너 1명이면 만점. rankScore = cap * (N - rank)/(N - 1).
  const rankScore =
    totalRunners <= 1 ? SCORE_CAPS.rank : clamp((SCORE_CAPS.rank * (totalRunners - rank)) / (totalRunners - 1), 0, SCORE_CAPS.rank);

  // 거리: 목표거리 대비 달성률(완주자는 1.0 → 만점). targetDistance≤0 방어.
  const ratio = goal.targetDistance > 0 ? clamp(runner.distanceKm / goal.targetDistance, 0, 1) : 0;
  const distanceScore = clamp(SCORE_CAPS.distance * ratio, 0, SCORE_CAPS.distance);

  // 완주 보너스: 단일 결정적 값. 미완주자 0.
  const finishBonus = runner.finished ? SCORE_CAPS.finishBonus : 0;

  // 여유: 제한시간 대비 남은 비율(빨리 끝낼수록 높음). 완주 + finishTime 있을 때만.
  const limitSeconds = goal.limitMinutes * 60;
  const marginScore =
    runner.finished && runner.finishTime != null && limitSeconds > 0
      ? clamp((SCORE_CAPS.margin * (limitSeconds - runner.finishTime)) / limitSeconds, 0, SCORE_CAPS.margin)
      : 0;

  const rounded = {
    rankScore: Math.round(rankScore),
    distanceScore: Math.round(distanceScore),
    finishBonus,
    marginScore: Math.round(marginScore),
  };
  const total = clamp(
    rounded.rankScore + rounded.distanceScore + rounded.finishBonus + rounded.marginScore,
    0,
    SCORE_CAPS.total
  );

  return { total, ...rounded };
}

/**
 * 적립 포인트(MVP 초안) — 점수 총합의 1/10을 반올림. 노출은 MVP 밖이지만 값은 계산해 저장한다.
 */
export function awardPoints(score: Score): number {
  return Math.round(score.total / 10);
}

/**
 * 경주 전체 결과 산출 — 순위 → 러너별 4축 점수 → 적립 포인트. (S4-1의 진입점)
 * 같은 입력이면 항상 같은 출력(정렬·계산 모두 결정적).
 */
export function computeRaceResults(goal: ScoreGoal, runners: RunnerInput[]): RunnerResult[] {
  const totalRunners = runners.length;
  return rankRunners(runners).map(({ runner, rank }) => {
    const score = scoreRunner(goal, runner, rank, totalRunners);
    return {
      userId: runner.userId,
      finished: runner.finished,
      distanceKm: runner.distanceKm,
      finishTime: runner.finishTime,
      rank,
      score,
      pointsAwarded: awardPoints(score),
    };
  });
}
