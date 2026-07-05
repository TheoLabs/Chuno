import { CalendarDate } from '@libs/types';
import { IsInt, IsString, Length } from 'class-validator';

export class RoomCreateDto {
  @IsString()
  @Length(1, 20)
  name: string;

  @IsInt()
  targetDistance: number;

  @IsInt()
  limitMinutes: number;

  @IsInt()
  maxParticipants: number;

  @IsString()
  scheduledStartOn: CalendarDate;
}
