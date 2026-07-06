import { CalendarDate } from '@libs/types';
import { ResponseDto } from '@libs/utils';
import { RoomStatus } from '@modules/room/domain/room.entity';
import { Exclude, Expose } from 'class-transformer';

@Exclude()
abstract class BaseRoomResponseDto extends ResponseDto {
  @Expose()
  id: number;

  @Expose()
  hostUserId: number;

  @Expose()
  name: string;

  @Expose()
  targetDistance: number;

  @Expose()
  limitMinutes: number;

  @Expose()
  maxParticipants: number;

  @Expose()
  scheduledStartOn: CalendarDate;

  @Expose()
  status: RoomStatus;
}

@Exclude()
export class GeneralRoomResponseDto extends BaseRoomResponseDto {
  @Expose()
  currentParticipantsCount: number;

  @Expose()
  isHost: boolean;
}
