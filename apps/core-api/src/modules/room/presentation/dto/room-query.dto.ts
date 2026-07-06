import { ToArray } from '@libs/decorators';
import { PaginationDto } from '@libs/utils';
import { RoomStatus } from '@modules/room/domain/room.entity';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional } from 'class-validator';

abstract class BaseRoomQueryDto extends PaginationDto {
  @ToArray()
  @IsEnum(RoomStatus, { each: true })
  @IsOptional()
  statuses?: RoomStatus[];

  @IsInt()
  @Type(() => Number)
  @IsOptional()
  minLimitMinutes: number;

  @IsInt()
  @Type(() => Number)
  @IsOptional()
  maxLimitMinutes: number;

  @IsInt()
  @Type(() => Number)
  @IsOptional()
  minTargetDistance: number;

  @IsInt()
  @Type(() => Number)
  @IsOptional()
  maxTargetDistance: number;
}

export class GeneralRoomQueryDto extends BaseRoomQueryDto {}
