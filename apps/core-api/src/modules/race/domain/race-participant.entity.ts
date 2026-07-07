import { DddBaseAggregate } from '@libs/ddd';
import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Race } from '@modules/race/domain/race.entity';

export enum RunnerStatus {
  RUNNING = 'running',
  FINISHED = 'finished',
  DNF = 'dnf', // did-not-finish: 제한시간 경과 시점 미완주자
  DISCONNECTED = 'disconnected',
}

/**
 * 안티치트 상한 속도 (S3-5).
 * 인간의 지속 러닝 속도 상한은 마라톤 세계기록(~20.9km/h)·단거리 피크(~37km/h)를 감안해도
 * 24km/h(= 2.5분/km)를 넘기기 어렵다. 보고 간격 Δt 동안 이 속도로 갈 수 있는 거리를 상한으로 삼아,
 * 그를 초과하는 급증(순간이동/GPS 튐/조작)은 리젝한다. 넉넉한 값이라 정상 러닝을 막지 않는다.
 */
export const MAX_FEASIBLE_SPEED_KMH = 24;
/** km per millisecond 환산 상수. */
export const MAX_FEASIBLE_KM_PER_MS = MAX_FEASIBLE_SPEED_KMH / 3_600_000;
/** float 비교 허용 오차(km). */
const EPSILON_KM = 1e-6;

export type ProgressResult = {
  accepted: boolean; // 보고가 진행에 반영됐는지(리젝이면 false, 상태 불변)
  finished: boolean; // 이 보고로 러너가 완주 상태가 됐는지
  reason?: 'not-running' | 'backward' | 'infeasible-pace';
};

type Ctor = {
  userId: number;
  startedAt: Date;
};

@Entity()
export class RaceParticipant extends DddBaseAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  raceId: number;

  @Column()
  userId: number;

  @Column({ type: 'float', comment: '누적 진행 거리(km) — 좌표 미수집, 서버 권위' })
  distanceKm: number;

  @Column({ type: 'enum', enum: RunnerStatus })
  status: RunnerStatus;

  @Column({ type: 'datetime', nullable: true, comment: '완주 시각(서버 UTC)' })
  finishedAt: Date | null;

  @Column({ type: 'datetime', comment: '마지막 진행 보고 시각(서버 UTC) — Δt 실현가능성 판정 기준' })
  lastReportAt: Date;

  @ManyToOne(() => Race, (race) => race.runners)
  @JoinColumn({ name: 'raceId' })
  race: Race;

  private constructor(args: Ctor) {
    super();

    if (args) {
      this.userId = args.userId;
      this.distanceKm = 0;
      this.status = RunnerStatus.RUNNING;
      this.finishedAt = null;
      this.lastReportAt = args.startedAt; // 출발 시각 기준으로 첫 Δt 계산
    }
  }

  static of(args: Ctor) {
    return new RaceParticipant(args);
  }

  /**
   * 진행 보고 반영 (S3-5 안티치트·클램프). 상태 불변식:
   * - RUNNING이 아니면(이미 완주/DNF/disconnected) 반영하지 않음.
   * - 역행(이전 거리 미만) 리젝.
   * - Δt 기준 실현가능 최대거리 초과(순간이동/비현실 페이스) 리젝.
   * - 목표거리 초과는 상한 클램프(초과분 버림).
   * - 반영 후 목표거리 도달 시 FINISHED + finishedAt.
   * 리젝 시 어떤 상태도 바뀌지 않는다(멱등적으로 무시).
   */
  report({ distanceKm, now, targetDistance }: { distanceKm: number; now: Date; targetDistance: number }): ProgressResult {
    if (this.status !== RunnerStatus.RUNNING) {
      return { accepted: false, finished: false, reason: 'not-running' };
    }

    // 역행 방지: 이전 누적거리보다 작으면 리젝.
    if (distanceKm < this.distanceKm - EPSILON_KM) {
      return { accepted: false, finished: false, reason: 'backward' };
    }

    const delta = distanceKm - this.distanceKm;
    const elapsedMs = now.getTime() - this.lastReportAt.getTime();

    // Δt≤0에 delta>0면 순간이동. Δt>0면 상한속도로 갈 수 있는 거리와 비교.
    if (delta > EPSILON_KM) {
      const maxFeasibleDelta = elapsedMs > 0 ? MAX_FEASIBLE_KM_PER_MS * elapsedMs : 0;
      if (delta > maxFeasibleDelta + EPSILON_KM) {
        return { accepted: false, finished: false, reason: 'infeasible-pace' };
      }
    }

    // 상한 클램프: 목표거리 초과분은 버린다.
    const clamped = Math.min(distanceKm, targetDistance);
    this.distanceKm = clamped;
    this.lastReportAt = now;

    if (clamped >= targetDistance - EPSILON_KM) {
      this.status = RunnerStatus.FINISHED;
      this.finishedAt = now;
      return { accepted: true, finished: true };
    }

    return { accepted: true, finished: false };
  }

  /** 경주 종료 시점 미완주자 처리(S3-6). RUNNING만 DNF로 확정(이미 FINISHED는 불변). */
  markDnfIfUnfinished(): void {
    if (this.status === RunnerStatus.RUNNING) {
      this.status = RunnerStatus.DNF;
    }
  }
}
