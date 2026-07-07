import { DddRepository } from '@libs/ddd';
import { convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';
import { Injectable } from '@nestjs/common';
import { Notification } from '@modules/notification/domain/notification.entity';

@Injectable()
export class NotificationRepository extends DddRepository<Notification> {
  entityClass = Notification;

  async find(
    conditions: { id?: number; userId?: number; dedupeKey?: string },
    options?: TypeormRelationOptions<Notification>
  ) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({ id: conditions.id, userId: conditions.userId, dedupeKey: conditions.dedupeKey }),
      ...convertOptions(options),
    });
  }

  async count(conditions: { id?: number; userId?: number; dedupeKey?: string }) {
    return this.entityManager.count(this.entityClass, {
      where: stripUndefined({ id: conditions.id, userId: conditions.userId, dedupeKey: conditions.dedupeKey }),
    });
  }

  /** 멱등 판정 — 같은 dedupeKey 알림이 이미 저장됐는지. */
  async existsByDedupeKey(dedupeKey: string): Promise<boolean> {
    return (await this.count({ dedupeKey })) > 0;
  }
}
