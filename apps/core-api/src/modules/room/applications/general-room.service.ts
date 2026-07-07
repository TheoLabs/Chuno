import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { CalendarDate } from '@libs/types';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { User } from '@modules/user/domain/user.entity';
import { Injectable, BadRequestException } from '@nestjs/common';
import { Room, RoomStatus } from '@modules/room/domain/room.entity';
import { Participant } from '@modules/room/domain/participant.entity';
import { PaginationOptions } from '@libs/utils';
import { GeneralRoomResponseDto } from '../presentation/dto/room-response.dto';
import { RoomScheduler } from './room-scheduler.service';

@Injectable()
export class GeneralRoomService extends DddService {
  constructor(
    private readonly roomRepository: RoomRepository,
    private readonly scheduler: RoomScheduler
  ) {
    super();
  }

  @Transactional()
  async create({
    user,
    name,
    targetDistance,
    limitMinutes,
    maxParticipants,
    scheduledStartOn,
  }: {
    user: User;
    name: string;
    targetDistance: number;
    limitMinutes: number;
    maxParticipants: number;
    scheduledStartOn: CalendarDate;
  }) {
    const hasAlreadyRecruitingRoom = await this.roomRepository.count({
      hostUserId: user.id,
      statuses: [RoomStatus.RECRUITING, RoomStatus.STARTING, RoomStatus.LIVE],
    });

    if (hasAlreadyRecruitingRoom >= 2) {
      throw new BadRequestException('이미 진행중인 방이 있습니다.', { description: '이미 진행중인 방이 있습니다.' });
    }

    const room = Room.of({
      name,
      hostUserId: user.id,
      targetDistance,
      limitMinutes,
      maxParticipants,
      scheduledStartOn,
      participant: Participant.of({ userId: user.id, isHost: true }),
    });

    await this.roomRepository.save([room]);

    // 예약 지연잡 등록(−10s STARTING / 정각 LIVE). 롤백돼도 잡은 없는 방을 로드해 no-op(멱등).
    await this.scheduler.schedule(room.id, room.scheduledStartOn);

    return { room: { id: room.id } };
  }

  async list(
    {
      user,
      statuses,
      minTargetDistance,
      maxTargetDistance,
      minLimitMinutes,
      maxLimitMinutes,
    }: {
      user: User;
      statuses?: RoomStatus[];
      minTargetDistance?: number;
      maxTargetDistance?: number;
      minLimitMinutes?: number;
      maxLimitMinutes?: number;
    },
    options?: PaginationOptions
  ) {
    const [rooms, total] = await Promise.all([
      this.roomRepository.find(
        { statuses, minLimitMinutes, maxLimitMinutes, minTargetDistance, maxTargetDistance },
        { options, relations: { participants: true } }
      ),
      this.roomRepository.count({ statuses, minLimitMinutes, maxLimitMinutes, minTargetDistance, maxTargetDistance }),
    ]);

    return {
      items: rooms.map((room) =>
        room.toInstance(GeneralRoomResponseDto, {
          currentParticipantsCount: room.participants.length,
          isHost: room.hostUserId === user.id,
        })
      ),
      total,
    };
  }

  /** 소켓 로비 참여 자격 검증용 — 해당 방의 Participant인지(REST로 이미 입장했는지) 확인. */
  async isParticipant(roomId: number, userId: number): Promise<boolean> {
    const [room] = await this.roomRepository.find({ id: roomId }, { relations: { participants: true } });
    return !!room && room.participants.some((participant) => participant.userId === userId);
  }

  async retrieve({ user, id }: { user: User; id: number }) {
    const [room] = await this.roomRepository.find({ id }, { relations: { participants: true } });

    if (!room) {
      throw new BadRequestException('존재하지 않는 방입니다.', { description: '존재하지 않는 방입니다.' });
    }

    return room.toInstance(GeneralRoomResponseDto, {
      currentParticipantsCount: room.participants.length,
      isHost: room.hostUserId === user.id,
    });
  }

  @Transactional()
  async cancel({ user, id }: { user: User; id: number }) {
    const [room] = await this.roomRepository.find({ id });

    if (!room) {
      throw new BadRequestException('존재하지 않는 방입니다.', { description: '존재하지 않는 방입니다.' });
    }

    room.cancel({ userId: user.id });

    await this.roomRepository.save([room]);
    await this.scheduler.cancel(room.id); // 예약 잡 제거(best-effort)
  }

  @Transactional()
  async join({ user, id }: { user: User; id: number }) {
    const [room] = await this.roomRepository.find({ id }, { relations: { participants: true } });

    if (!room) {
      throw new BadRequestException('존재하지 않는 방입니다.', { description: '존재하지 않는 방입니다.' });
    }

    room.join({ userId: user.id });

    await this.roomRepository.save([room]);
  }

  @Transactional()
  async leave({ user, id }: { user: User; id: number }) {
    const [room] = await this.roomRepository.find({ id }, { relations: { participants: true } });

    if (!room) {
      throw new BadRequestException('존재하지 않는 방입니다.', { description: '존재하지 않는 방입니다.' });
    }

    room.leave({ userId: user.id });

    await this.roomRepository.save([room]);
    // 호스트 이탈이면 방이 취소됨 → 예약 잡 제거.
    if (room.status === RoomStatus.CANCELLED) {
      await this.scheduler.cancel(room.id);
    }
  }

  /** 예약 −10초 트리거(스케줄러 잡). RECRUITING→STARTING(2명 미만이면 CANCELLED). 멱등. */
  @Transactional()
  async markStarting(id: number) {
    const [room] = await this.roomRepository.find({ id }, { relations: { participants: true } });
    if (!room) return; // 삭제/롤백된 방 — no-op

    room.markStarting();
    await this.roomRepository.save([room]);

    // 2명 미만으로 취소됐다면 남은 markLive 잡 제거(best-effort).
    if (room.status === RoomStatus.CANCELLED) {
      await this.scheduler.cancel(room.id);
    }
  }

  /** 예약 정각 트리거(스케줄러 잡). STARTING→LIVE. 멱등. */
  @Transactional()
  async markLive(id: number) {
    const [room] = await this.roomRepository.find({ id });
    if (!room) return;

    room.markLive();
    await this.roomRepository.save([room]);
  }
}
