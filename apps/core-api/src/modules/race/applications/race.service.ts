import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { Injectable, Logger } from '@nestjs/common';
import { RaceRepository } from '@modules/race/infrastructure/race.repository';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { RoomStatus } from '@modules/room/domain/room.entity';
import { Race, RaceStatus } from '@modules/race/domain/race.entity';
import { ProgressResult } from '@modules/race/domain/race-participant.entity';
import { RaceScheduler } from './race-scheduler.service';

export type LeaderboardEntry = {
  rank: number;
  userId: number;
  distanceKm: number;
  status: string;
  finishedAt: number | null; // epoch millis
};

export type LeaderboardSnapshot = {
  roomId: number;
  status: RaceStatus;
  startedAt: number;
  goal: { targetDistance: number; limitMinutes: number };
  runners: LeaderboardEntry[];
};

/**
 * 경주 애플리케이션 서비스 (S3-3~S3-6).
 *
 * - `createFromRoom`: RoomLive 트리거로 방 참가자 전원을 러너로 하는 Race 생성(멱등) + 제한시간 finalize 지연잡.
 * - `reportProgress`: 러너 거리 보고 반영(도메인이 안티치트·클램프 검증) 후 영속.
 * - `finalize`: 제한시간 지연잡/조기종료 진입점 — 도메인 finalize가 멱등이라 재호출에도 결과 불변.
 * - `getLeaderboard`: 거리 내림차순 스냅샷(게이트웨이 주기 브로드캐스트용).
 */
@Injectable()
export class RaceService extends DddService {
  private readonly logger = new Logger(RaceService.name);

  constructor(
    private readonly raceRepository: RaceRepository,
    private readonly roomRepository: RoomRepository,
    private readonly scheduler: RaceScheduler
  ) {
    super();
  }

  /** 방 LIVE → Race 생성(S3-3). 이미 방에 Race가 있으면 no-op(멱등 — 중복 RoomLive 방어). */
  @Transactional()
  async createFromRoom(roomId: number): Promise<void> {
    const existing = await this.raceRepository.count({ roomId });
    if (existing > 0) return; // 이미 생성됨 — 멱등

    const [room] = await this.roomRepository.find({ id: roomId }, { relations: { participants: true } });
    if (!room) return; // 롤백/삭제된 방 — no-op
    if (room.status !== RoomStatus.LIVE) return; // LIVE 전환 커밋 후에만 생성

    const startedAt = new Date(); // 서버 권위 시각(전원 동일 startedAt)
    const race = Race.create({
      roomId: room.id,
      goal: { targetDistance: room.targetDistance, limitMinutes: room.limitMinutes },
      runnerUserIds: room.participants.map((p) => p.userId),
      startedAt,
    });

    await this.raceRepository.save([race]);
    // 제한시간 만료 시 finalize 지연잡(멱등 finalize라 조기종료 시 no-op).
    await this.scheduler.scheduleFinalize(room.id, startedAt, room.limitMinutes);
  }

  /** 러너 진행 보고 반영(S3-4/S3-5). 반영 결과(수락/리젝/완주)를 반환. */
  @Transactional()
  async reportProgress({
    roomId,
    userId,
    distanceKm,
  }: {
    roomId: number;
    userId: number;
    distanceKm: number;
  }): Promise<ProgressResult> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    if (!race) return { accepted: false, finished: false, reason: 'not-running' };

    const result = race.report({ userId, distanceKm, now: new Date() });
    await this.raceRepository.save([race]);
    return result;
  }

  /** 종료 확정(S3-6) — 제한시간 지연잡/명시 호출. 도메인 finalize가 멱등. */
  @Transactional()
  async finalize(roomId: number): Promise<void> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    if (!race) return;
    if (race.status === RaceStatus.FINISHED) return; // 멱등 조기반환(불필요 save 방지)

    race.finalize(new Date());
    await this.raceRepository.save([race]);
    await this.scheduler.cancel(roomId); // 남은 지연잡 제거(best-effort)
  }

  /** 소켓 '/race' 참여 자격 검증 — 해당 방 Race의 러너인지. */
  async isRunner(roomId: number, userId: number): Promise<boolean> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    return !!race && race.runners.some((runner) => runner.userId === userId);
  }

  /** 리더보드 스냅샷(읽기) — 거리 내림차순. 없으면 null. */
  async getLeaderboard(roomId: number): Promise<LeaderboardSnapshot | null> {
    const [race] = await this.raceRepository.find({ roomId }, { relations: { runners: true } });
    if (!race) return null;

    return {
      roomId: race.roomId,
      status: race.status,
      startedAt: race.startedAt.getTime(),
      goal: race.goal,
      runners: race.leaderboard().map((runner, index) => ({
        rank: index + 1,
        userId: runner.userId,
        distanceKm: runner.distanceKm,
        status: runner.status,
        finishedAt: runner.finishedAt ? runner.finishedAt.getTime() : null,
      })),
    };
  }
}
