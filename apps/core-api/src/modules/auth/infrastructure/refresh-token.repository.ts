import { DddRepository } from '@libs/ddd';
import { Injectable } from '@nestjs/common';
import { RefreshToken } from '../domain/refresh-token.entity';

@Injectable()
export class RefreshTokenRepository extends DddRepository<RefreshToken> {
  entityClass = RefreshToken;

  findByHash(tokenHash: string) {
    return this.entityManager.findOne(this.entityClass, { where: { tokenHash } });
  }

  findByFamily(familyId: string) {
    return this.entityManager.find(this.entityClass, { where: { familyId } });
  }
}
