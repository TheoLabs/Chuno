import { DddAggregate } from '@libs/ddd';
import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';
import { RunnerResult } from './scoring';

type CreateArgs = {
  raceId: number;
  result: RunnerResult;
};

/**
 * RaceResult 애그리거트 (S4-2) — 종료된 경주의 러너 1명분 확정 결과.
 *
 * RaceFinished 구독 핸들러가 러너별 순위·점수(Score VO 컬럼)를 산출해 N건 저장한다.
 * (raceId, userId) 유니크 — 중복 이벤트에도 1건만 남아 멱등. Score VO는 별도 테이블 없이 컬럼들로 임베드.
 * 시각은 자동 감사 타임스탬프(createdAt/UTC)만 사용 — 결과는 종료 시점 1회 스냅샷이라 별도 비즈니스 날짜 불필요.
 */
@Entity()
@Index('idx_race_result_race_user', ['raceId', 'userId'], { unique: true })
export class RaceResult extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ comment: '원본 Race Id' })
  raceId: number;

  @Column()
  userId: number;

  @Column({ comment: '완주 여부' })
  finished: boolean;

  @Column({ type: 'float', comment: '최종 누적 거리(km)' })
  distanceKm: number;

  @Column({ type: 'float', nullable: true, comment: '완주 소요(초, startedAt~finishedAt) — 미완주자 null' })
  finishTime: number | null;

  @Column({ comment: '최종 순위(완주자 finishTime 오름차순 → 미완주자 거리 내림차순)' })
  rank: number;

  // Score VO(임베드) — 서버 권위 4축 + 합계.
  @Column({ comment: '점수 합계(≤1000)' })
  total: number;

  @Column({ comment: '등수 점수(≤300)' })
  rankScore: number;

  @Column({ comment: '거리 점수(≤200)' })
  distanceScore: number;

  @Column({ comment: '완주 보너스(220 or 0)' })
  finishBonus: number;

  @Column({ comment: '여유 점수(≤100)' })
  marginScore: number;

  @Column({ comment: '적립 포인트(MVP 초안)' })
  pointsAwarded: number;

  private constructor(args: CreateArgs) {
    super();

    if (args) {
      const { raceId, result } = args;
      this.raceId = raceId;
      this.userId = result.userId;
      this.finished = result.finished;
      this.distanceKm = result.distanceKm;
      this.finishTime = result.finishTime;
      this.rank = result.rank;
      this.total = result.score.total;
      this.rankScore = result.score.rankScore;
      this.distanceScore = result.score.distanceScore;
      this.finishBonus = result.score.finishBonus;
      this.marginScore = result.score.marginScore;
      this.pointsAwarded = result.pointsAwarded;
    }
  }

  static of(args: CreateArgs): RaceResult {
    return new RaceResult(args);
  }
}
