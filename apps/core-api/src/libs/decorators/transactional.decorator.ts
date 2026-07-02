import { ContextKey } from '@libs/context';
import { InternalServerErrorException } from '@nestjs/common';
import { DddService } from '@libs/ddd';

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

      if (!context || !entityManager) {
        throw new InternalServerErrorException('Context or Datasource instance is not existed.');
      }

      // NOTE: 도메인 이벤트는 Repository.save() 에서 같은 트랜잭션으로 ddd_events(아웃박스)에 적재되고,
      //       Debezium CDC → Kafka 로 전파된다. 별도 in-memory emit 경로는 두지 않는다.
      //  NOTE: 해당 방식은 무조건 transaction() 메서드가 제공하는 entityManager를 사용하여야한다. https://typeorm.io/docs/advanced-topics/transactions
      await entityManager.transaction(async (transactionEntityManager) => {
        try {
          context.set(ContextKey.ENTITY_MANAGER, transactionEntityManager);
          result = await originalMethod.apply(this, args);
        } finally {
          context.set(ContextKey.ENTITY_MANAGER, null);
        }
      });

      return result;
    };
    return descriptor;
  };
}
