import { DddService } from '@libs/ddd';
import { BadRequestException, Injectable } from '@nestjs/common';
import { UserRepository } from '../infrastructure/user.repository';
import { Transactional } from '@libs/decorators';
import { RunnerLevel, User } from '../domain/user.entity';
import { LegalDocumentRepository } from '@modules/legal-document/infrastructure/legal-document.repository';

@Injectable()
export class GeneralUserService extends DddService {
  constructor(
    private readonly userRepository: UserRepository,
    private readonly legalDocumentRepository: LegalDocumentRepository
  ) {
    super();
  }

  async checkAvailableNickname({ nickname }: { nickname: string }) {
    const count = await this.userRepository.count({ nickname });

    return { usedCount: count };
  }

  @Transactional()
  async onboard({
    user,
    nickname,
    level,
    legalDocumentIds,
  }: {
    user: User;
    nickname: string;
    level: RunnerLevel;
    legalDocumentIds: number[];
  }) {
    // NOTE: 이미 가드를 지나쳐온 User와 동일하므로 존재 유무 검증은 필요없음.
    const [userWithConsents] = await this.userRepository.find({ id: user.id }, { relations: { consents: true } });

    const [existingNickname] = await this.userRepository.find({ nickname });

    if (existingNickname) {
      throw new BadRequestException('중복된 닉네임입니다.', { description: '중복된 닉네임입니다.' });
    }

    const legalDocuments = await this.legalDocumentRepository.find({ ids: legalDocumentIds });

    userWithConsents.onboard({ nickname, level, legalDocuments });

    await this.userRepository.save([userWithConsents]);
  }
}
