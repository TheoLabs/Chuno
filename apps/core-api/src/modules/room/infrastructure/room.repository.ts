import { DddRepository } from '@libs/ddd';
import { checkInValue, checkRangeValue, convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';
import { Room, RoomStatus } from '@modules/room/domain/room.entity';
import { Injectable } from '@nestjs/common';

@Injectable()
export class RoomRepository extends DddRepository<Room> {
  entityClass = Room;

  async find(
    conditions: {
      id?: number;
      hostUserId?: number;
      statuses?: RoomStatus[];
      minTargetDistance?: number;
      maxTargetDistance?: number;
      minLimitMinutes?: number;
      maxLimitMinutes?: number;
    },
    options?: TypeormRelationOptions<Room>
  ) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        hostUserId: conditions.hostUserId,
        status: checkInValue(conditions.statuses),
        targetDistance: checkRangeValue(conditions.minTargetDistance, conditions.maxTargetDistance),
        limitMinutes: checkRangeValue(conditions.minLimitMinutes, conditions.maxLimitMinutes),
      }),
      ...convertOptions(options),
    });
  }

  async count(conditions: {
    id?: number;
    hostUserId?: number;
    statuses?: RoomStatus[];
    minTargetDistance?: number;
    maxTargetDistance?: number;
    minLimitMinutes?: number;
    maxLimitMinutes?: number;
  }) {
    return this.entityManager.count(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        hostUserId: conditions.hostUserId,
        status: checkInValue(conditions.statuses),
        targetDistance: checkRangeValue(conditions.minTargetDistance, conditions.maxTargetDistance),
        limitMinutes: checkRangeValue(conditions.minLimitMinutes, conditions.maxLimitMinutes),
      }),
    });
  }
}
