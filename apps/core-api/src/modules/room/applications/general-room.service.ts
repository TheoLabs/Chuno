import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { CalendarDate } from '@libs/types';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { User } from '@modules/user/domain/user.entity';
import { Injectable, BadRequestException } from '@nestjs/common';
import { Room, RoomStatus } from '@modules/room/domain/room.entity';
import { Participant } from '@modules/room/domain/participant.entity';

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
  }
}
