import { DddAggregate } from '@libs/ddd';
import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/**
 * RaceStatApplied (S4-3 멱등 마커) — 이 raceId가 RunnerStats 누적에 이미 반영됐음을 표시.
 *
 * RunnerStats는 누적 카운터라 같은 경주를 두 번 더하면 오염된다(RaceResult처럼 유니크로 자연 멱등이 안 됨).
 * 그래서 누적과 **같은 트랜잭션**에서 raceId 마커를 1건 심고, raceId 유니크로 중복 반영을 막는다.
 * RaceResult 존재 여부에 의존하지 않는 독립 마커 — S4-2/S4-3가 서로 다른 트랜잭션으로 동시 실행돼도 안전.
 */
@Entity()
@Index('idx_race_stat_applied_race', ['raceId'], { unique: true })
export class RaceStatApplied extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ comment: 'RunnerStats 누적에 반영된 Race Id' })
  raceId: number;

  private constructor(raceId?: number) {
    super();
    if (raceId != null) this.raceId = raceId;
  }

  static of(raceId: number): RaceStatApplied {
    return new RaceStatApplied(raceId);
  }
}
