import { Context } from 'src/libs/context';
import { Inject } from '@nestjs/common';
import { InjectEntityManager } from '@nestjs/typeorm';
import { EntityManager } from 'typeorm';
import { DomainEventPublisher } from './domain-event-publisher';

export abstract class DddService {
  @InjectEntityManager()
  private readonly entityManager!: EntityManager;

  @Inject()
  private readonly context!: Context;

  // 커밋 후 인프로세스 도메인 이벤트 발행에 사용(@Transactional 데코레이터가 참조). QueueModule(전역)에서 제공.
  @Inject(DomainEventPublisher)
  private readonly eventPublisher!: DomainEventPublisher;
}
