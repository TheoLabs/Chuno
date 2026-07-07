import { DddRepository } from '@libs/ddd';
import { checkInValue, convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';
import { Injectable } from '@nestjs/common';
import { DeviceToken } from '@modules/notification/domain/device-token.entity';

@Injectable()
export class DeviceTokenRepository extends DddRepository<DeviceToken> {
  entityClass = DeviceToken;

  async find(
    conditions: { id?: number; userId?: number; userIds?: number[]; token?: string },
    options?: TypeormRelationOptions<DeviceToken>
  ) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        userId: checkInValue(conditions.userIds) ?? conditions.userId,
        token: conditions.token,
      }),
      ...convertOptions(options),
    });
  }

  /** 여러 유저의 기기 토큰을 한 번에 로드(멀티캐스트 대상 수집). */
  async findByUserIds(userIds: number[]): Promise<DeviceToken[]> {
    if (userIds.length === 0) return [];
    return this.find({ userIds });
  }
}
