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

@Injectable()
export class GeneralRoomService extends DddService {
  constructor(private readonly roomRepository: RoomRepository) {
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
  }
}
