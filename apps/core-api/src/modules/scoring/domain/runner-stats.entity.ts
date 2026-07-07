import { DddAggregate } from '@libs/ddd';
import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/** 러너 티어 — 누적 점수 기반(MVP 임시 컷). 브론즈 → 다이아. */
export enum RunnerTier {
  BRONZE = 'bronze',
  SILVER = 'silver',
  GOLD = 'gold',
  PLATINUM = 'platinum',
  DIAMOND = 'diamond',
}

/**
 * 티어 컷(MVP 임시) — 누적 totalScore 기준. 경주 1회 최대 ~1000점이라
 * 대략 (브론즈) 초심자 → (실버) 몇 경기 → (골드) 꾸준 → (플래) 상위 → (다이아) 최상위로 잡았다.
 * 밸런싱 데이터가 쌓이면 재조정한다.
 */
const TIER_CUTS: { tier: RunnerTier; min: number }[] = [
  { tier: RunnerTier.DIAMOND, min: 10000 },
  { tier: RunnerTier.PLATINUM, min: 6000 },
  { tier: RunnerTier.GOLD, min: 3000 },
  { tier: RunnerTier.SILVER, min: 1000 },
  { tier: RunnerTier.BRONZE, min: 0 },
];

export function tierOf(totalScore: number): RunnerTier {
  return (TIER_CUTS.find((cut) => totalScore >= cut.min) ?? TIER_CUTS[TIER_CUTS.length - 1]).tier;
}

type ApplyArgs = {
  scoreTotal: number;
  distanceKm: number;
  isWin: boolean;
};

/**
 * RunnerStats 애그리거트 (S4-3) — 유저별 누적 통계. userId 유니크(유저 1인 1행).
 *
 * RaceFinished마다 러너별로 누적(totalScore·totalDistanceKm·raceCount·winCount) + 티어 재산출.
 * 멱등은 애그리거트 밖(RaceStatApplied 마커 + 유니크)에서 보장 — 여기선 순수 누적만.
 */
@Entity()
@Index('idx_runner_stats_user', ['userId'], { unique: true })
export class RunnerStats extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  userId: number;

  @Column({ default: 0, comment: '누적 점수' })
  totalScore: number;

  @Column({ type: 'float', default: 0, comment: '누적 거리(km)' })
  totalDistanceKm: number;

  @Column({ default: 0, comment: '참가 경주 수' })
  raceCount: number;

  @Column({ default: 0, comment: '우승(1등) 수' })
  winCount: number;

  @Column({ type: 'enum', enum: RunnerTier, default: RunnerTier.BRONZE })
  tier: RunnerTier;

  private constructor(userId?: number) {
    super();
    if (userId != null) {
      this.userId = userId;
      this.totalScore = 0;
      this.totalDistanceKm = 0;
      this.raceCount = 0;
      this.winCount = 0;
      this.tier = RunnerTier.BRONZE;
    }
  }

  /** 최초 통계(0에서 시작). */
  static create(userId: number): RunnerStats {
    return new RunnerStats(userId);
  }

  /** 경주 1건 결과 누적 + 티어 재산출. 멱등 보장은 호출부(마커)가 책임진다. */
  apply({ scoreTotal, distanceKm, isWin }: ApplyArgs): void {
    this.totalScore += scoreTotal;
    this.totalDistanceKm += distanceKm;
    this.raceCount += 1;
    if (isWin) this.winCount += 1;
    this.tier = tierOf(this.totalScore);
  }
}
