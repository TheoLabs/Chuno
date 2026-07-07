import { DddAggregate } from '@libs/ddd';
import { Column, Entity, Index, OneToMany, PrimaryGeneratedColumn } from 'typeorm';
import { RaceParticipant, RunnerStatus, ProgressResult } from '@modules/race/domain/race-participant.entity';
import { RaceStarted, RunnerFinished, RaceFinished } from '@modules/race/domain/events/race.events';

export enum RaceStatus {
  LIVE = 'live',
  FINISHED = 'finished',
}

/** 경주 목표 — 목표거리(km)와 제한시간(분). Room 설정에서 승계. */
export type RaceGoal = {
  targetDistance: number; // km
  limitMinutes: number;
};

type CreateArgs = {
  roomId: number;
  goal: RaceGoal;
  runnerUserIds: number[];
  startedAt: Date;
};

/**
 * Race 애그리거트 (S3-3~S3-6) — 방 LIVE 전환 시 생성되는 실시간 경주.
 *
 * 좌표를 받지 않고 **거리만** 서버 권위로 집계한다(안티치트는 RaceParticipant.report). 시각은 모두 서버 UTC(Date).
 * 도메인 이벤트(RaceStarted/RunnerFinished/RaceFinished)는 publishEvent로 수집 → 커밋 후 인프로세스 발행.
 */
@Entity()
// roomId 유니크 — 방 1개당 Race 1개(단일 발행자 markLive 멱등 + DB 레벨 중복생성 방지).
@Index('idx_race_room_id', ['roomId'], { unique: true })
export class Race extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ comment: '원본 방 Id' })
  roomId: number;

  @Column({ type: 'json', comment: '목표거리(km)·제한시간(분)' })
  goal: RaceGoal;

  @Column({ type: 'datetime', comment: '출발 시각(서버 UTC, 동시 출발 기준)' })
  startedAt: Date;

  @Column({ type: 'datetime', nullable: true, comment: '종료 시각(서버 UTC)' })
  endedAt: Date | null;

  @Column({ type: 'enum', enum: RaceStatus })
  status: RaceStatus;

  @OneToMany(() => RaceParticipant, (runner) => runner.race, { cascade: true, orphanedRowAction: 'delete' })
  runners: RaceParticipant[];

  private constructor(args: CreateArgs) {
    super();

    if (args) {
      this.roomId = args.roomId;
      this.goal = args.goal;
      this.startedAt = args.startedAt;
      this.endedAt = null;
      this.status = RaceStatus.LIVE;
      this.runners = args.runnerUserIds.map((userId) => RaceParticipant.of({ userId, startedAt: args.startedAt }));
    }
  }

  /** 방 LIVE → Race 생성(S3-3). 참가자 전원 RUNNING, 동일 startedAt. RaceStarted 발행. */
  static create(args: CreateArgs): Race {
    const race = new Race(args);
    race.publishEvent(
      new RaceStarted(args.roomId, args.startedAt.getTime(), args.goal.targetDistance, args.goal.limitMinutes)
    );
    return race;
  }

  /**
   * 러너 진행 보고 반영(S3-4/S3-5). 검증/클램프는 RaceParticipant.report에 위임.
   * 완주 시 RunnerFinished 수집, 전원 완주면 자동 finalize.
   */
  report({ userId, distanceKm, now }: { userId: number; distanceKm: number; now: Date }): ProgressResult {
    if (this.status !== RaceStatus.LIVE) {
      return { accepted: false, finished: false, reason: 'not-running' };
    }

    const runner = this.runners.find((r) => r.userId === userId);
    if (!runner) {
      return { accepted: false, finished: false, reason: 'not-running' };
    }

    const result = runner.report({ distanceKm, now, targetDistance: this.goal.targetDistance });

    if (result.finished) {
      this.publishEvent(new RunnerFinished(this.roomId, userId, now.getTime()));
      // 전원 완주 시 즉시 종료(제한시간 지연잡을 기다리지 않고 마감).
      if (this.runners.every((r) => r.status === RunnerStatus.FINISHED)) {
        this.finalize(now);
      }
    }

    return result;
  }

  /**
   * 종료 확정(S3-6) — 멱등. 이미 FINISHED면 no-op(중복 호출/재시작에도 결과 불변).
   * 아니면 status=FINISHED·endedAt 설정, 미완주자 DNF, RaceFinished 발행.
   */
  finalize(now: Date): void {
    if (this.status === RaceStatus.FINISHED) return;

    this.status = RaceStatus.FINISHED;
    this.endedAt = now;
    this.runners.forEach((runner) => runner.markDnfIfUnfinished());
    this.publishEvent(new RaceFinished(this.roomId));
  }

  /** 리더보드 — 거리 내림차순 정렬 러너 목록(순위는 조회 측에서 index+1). */
  leaderboard(): RaceParticipant[] {
    return [...this.runners].sort((a, b) => b.distanceKm - a.distanceKm);
  }
}
