import { ContextKey } from '@libs/context';
import { InternalServerErrorException, Logger } from '@nestjs/common';
import { DddService, DddEvent } from '@libs/ddd';

const logger = new Logger('Transactional');

export function Transactional() {
  return function (target: DddService, propertyKey: string, descriptor: PropertyDescriptor) {
    // NOTE: 적용된 메서드의 function
    const originalMethod = descriptor.value;

    descriptor.value = async function (this: DddService, ...args: any[]) {
      let result: any;

      // @ts-expect-error private으로 되어있어서 타입에러 발생.
      const context = this.context;
      // @ts-expect-error private으로 되어있어서 타입에러 발생.
      const entityManager = this.entityManager;
      // @ts-expect-error private으로 되어있어서 타입에러 발생.
      const eventPublisher = this.eventPublisher;

      if (!context || !entityManager) {
        throw new InternalServerErrorException('Context or Datasource instance is not existed.');
      }

      // NOTE: 도메인 이벤트는 두 경로로 나간다.
      //   (1) 아웃박스: Repository.save()가 같은 트랜잭션으로 ddd_events에 적재 → Debezium CDC → Kafka(크로스서비스 durable).
      //   (2) 인프로세스: Repository.save()가 ALS(DDD_EVENTS)에 수집한 원본 이벤트를 **커밋 성공 후** BullMQ로 발행(아래).
      //  NOTE: 해당 방식은 무조건 transaction() 메서드가 제공하는 entityManager를 사용하여야한다. https://typeorm.io/docs/advanced-topics/transactions
      try {
        await entityManager.transaction(async (transactionEntityManager) => {
          try {
            context.set(ContextKey.ENTITY_MANAGER, transactionEntityManager);
            result = await originalMethod.apply(this, args);
          } finally {
            context.set(ContextKey.ENTITY_MANAGER, null);
          }
        });
      } catch (error) {
        // 롤백 — 수집된 이벤트는 폐기(발행하지 않는다).
        context.set(ContextKey.DDD_EVENTS, []);
        throw error;
      }

      // 커밋 성공 후 인프로세스 발행. 실패는 **비치명적**(이미 커밋된 상태 변경을 되돌리지 않음) — 로깅만.
      const events = (context.get<DddEvent[]>(ContextKey.DDD_EVENTS) ?? []).slice();
      context.set(ContextKey.DDD_EVENTS, []);
      if (events.length && eventPublisher) {
        try {
          await eventPublisher.publish(events);
        } catch (error) {
          logger.error(`도메인 이벤트 발행 실패(커밋은 완료됨): ${(error as Error).message}`, (error as Error).stack);
        }
      }

      return result;
    };
    return descriptor;
  };
}
