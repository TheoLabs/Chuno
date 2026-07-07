import { EntityManager, ObjectType, DataSource } from 'typeorm';
import { DddAggregate } from './ddd-aggregate';
import { InjectDataSource } from '@nestjs/typeorm';
import { Context, ContextKey } from 'src/libs/context';
import { DddEvent } from './ddd-event';

export abstract class DddRepository<T extends DddAggregate> {
  constructor(
    @InjectDataSource() private readonly datasource: DataSource,
    private readonly context: Context
  ) {}

  abstract entityClass: ObjectType<T>;

  get entityManager(): EntityManager {
    // NOTE: Context의 entityManager를 꺼내오는 경우는, @Transaction()으로 인한 Transaction entityManager를 가져오기 위함.
    return this.context.get<EntityManager>(ContextKey.ENTITY_MANAGER) || this.datasource.manager;
  }

  createQueryBuilder(alias: string) {
    return this.entityManager.createQueryBuilder<T>(this.entityClass, alias);
  }

  async save(entities: T[]) {
    await this.saveEntities(entities);
    await this.saveEvents(entities.flatMap((entity) => entity.getPublishedEvents()));
  }

  async softRemove(entities: T[]) {
    await this.saveEvents(entities.flatMap((entity) => entity.getPublishedEvents()));
    await this.entityManager.softRemove(entities);
  }

  /**
   * 하드 삭제 + 도메인 이벤트 아웃박스 적재(같은 트랜잭션).
   * cross-aggregate 정리(예: Episode 삭제 → Cut)를 EDA로 잇기 위해, 삭제 시점에도 이벤트를 발행한다.
   * 발행할 이벤트가 없으면 단순 하드 삭제.
   */
  async remove(entities: T[]) {
    await this.saveEvents(entities.flatMap((entity) => entity.getPublishedEvents()));
    await this.entityManager.remove(entities);
  }

  private async saveEntities(entities: T[]) {
    const traceId = this.context.get<string>(ContextKey.TXID);
    entities.forEach((entity) => entity.setTraceId(traceId));
    await this.entityManager.save(entities);
  }

  private async saveEvents(events: DddEvent[]) {
    if (events.length === 0) return;

    // (1) 인프로세스 발행용: 원본 도메인 이벤트를 ALS 컨텍스트에 수집한다.
    //     @Transactional 데코레이터가 커밋 성공 후 이 수집분을 BullMQ(domain-events)로 발행한다(팬텀 방지).
    const collected = this.context.get<DddEvent[]>(ContextKey.DDD_EVENTS) ?? [];
    collected.push(...events);
    this.context.set(ContextKey.DDD_EVENTS, collected);

    // (2) 아웃박스: 같은 트랜잭션으로 ddd_events에 적재 → Debezium CDC → Kafka(크로스서비스 durable).
    const traceId = this.context.get<string>(ContextKey.TXID);
    const dddEvents = events.map((event) => DddEvent.fromEvent(event));
    dddEvents.forEach((event) => event.setTraceId(traceId));
    await this.entityManager.save(dddEvents);
  }
}
