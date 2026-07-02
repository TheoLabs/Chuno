import { DddRepository } from '@libs/ddd';
import { Injectable } from '@nestjs/common';
import { User } from '../domain/user.entity';
import { AuthProvider } from '../domain/auth-identity.entity';
import { convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';

@Injectable()
export class UserRepository extends DddRepository<User> {
  entityClass = User;

  async findBySocialIdentity(provider: AuthProvider, sub: string) {
    return this.entityManager.findOne(this.entityClass, {
      where: { authIdentity: { provider, sub } },
      relations: { authIdentity: true },
    });
  }

  async find(conditions: { id?: number; nickname?: string }, options?: TypeormRelationOptions<User>) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        nickname: conditions.nickname,
      }),
      ...convertOptions(options),
    });
  }

  async count(conditions: { id?: number; nickname?: string }) {
    return this.entityManager.count(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        nickname: conditions.nickname,
      }),
    });
  }
}
