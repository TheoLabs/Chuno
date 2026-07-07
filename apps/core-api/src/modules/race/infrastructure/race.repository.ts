import { DddRepository } from '@libs/ddd';
import { convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';
import { Race } from '@modules/race/domain/race.entity';
import { Injectable } from '@nestjs/common';

@Injectable()
export class RaceRepository extends DddRepository<Race> {
  entityClass = Race;

  async find(conditions: { id?: number; roomId?: number }, options?: TypeormRelationOptions<Race>) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({ id: conditions.id, roomId: conditions.roomId }),
      ...convertOptions(options),
    });
  }

  async count(conditions: { id?: number; roomId?: number }) {
    return this.entityManager.count(this.entityClass, {
      where: stripUndefined({ id: conditions.id, roomId: conditions.roomId }),
    });
  }
}
