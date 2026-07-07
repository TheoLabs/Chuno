import { Global, Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ConfigsService } from '@configs';
import { DomainEventPublisher } from '@libs/ddd';
import { QUEUE } from './queue.constants';
import { QueueHealthIndicator } from './queue-health.service';
import { BullDomainEventPublisher } from './bull-domain-event-publisher';

/**
 * Redis / BullMQ 인프라 — 전역 모듈 (S2-12).
 *
 * 예약 스케줄러(S2-3 지연잡)와 인프로세스 도메인 이벤트 디스패치(S2-5)가 기대는 큐 기반.
 * 커넥션은 `@configs`의 redis 설정(로컬 docker `localhost:6379` 기본)에서 가져온다.
 *
 * - `forRootAsync`로 기본 커넥션을 등록 → 각 도메인 모듈은 `BullModule.registerQueue({ name })`로
 *   이 커넥션을 공유해 큐/워커를 선언한다.
 * - 여기서 지연잡용 `ROOM_SCHEDULER` 큐를 등록·재노출하고, 부팅 헬스체크(QueueHealthIndicator)를 건다.
 * - 스코프외: socket.io Redis 어댑터(단일 인스턴스라 불필요).
 */
@Global()
@Module({
  imports: [
    BullModule.forRootAsync({
      inject: [ConfigsService],
      useFactory: (configs: ConfigsService) => ({
        connection: { host: configs.redis.host, port: configs.redis.port },
      }),
    }),
    BullModule.registerQueue({ name: QUEUE.ROOM_SCHEDULER }, { name: QUEUE.DOMAIN_EVENTS }),
  ],
  providers: [
    QueueHealthIndicator,
    BullDomainEventPublisher,
    // 도메인 이벤트 발행 포트 → BullMQ 구현 바인딩(DddService가 포트로 주입받아 커밋 후 발행).
    { provide: DomainEventPublisher, useExisting: BullDomainEventPublisher },
  ],
  exports: [BullModule, QueueHealthIndicator, DomainEventPublisher],
})
export class QueueModule {}
