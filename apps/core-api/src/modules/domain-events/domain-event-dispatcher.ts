import { Logger, OnModuleInit } from '@nestjs/common';
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { DiscoveryService } from '@nestjs/core';
import type { Job } from 'bullmq';
import { QUEUE, DomainEventHandler } from '@libs/queue';
import { runWithContext } from '@libs/context';

/**
 * 도메인 이벤트 팬아웃 디스패처 (S3-3 리팩터) — `domain-events` 큐의 **유일한** 워커.
 *
 * BullMQ 잡은 큐당 워커 한 곳에만 배달되므로 소비자별 `@Processor`를 여러 개 두면 이벤트가 갈린다.
 * 그래서 워커는 이 디스패처 하나만 두고, 실제 소비는 인프로세스로 팬아웃한다:
 *   - 부팅 시 `DiscoveryService`로 모든 `DomainEventHandler` 프로바이더를 수집(모듈 간 결합 없이 등록만으로 확장).
 *   - 잡 수신 시 `supports(job.name)`가 참인 핸들러에 `handle` 위임.
 *   - 각 핸들러 예외는 격리·로깅 — 한 핸들러 실패가 다른 핸들러/잡을 막지 않는다.
 *
 * 이 구조 덕에 새 소비자(예: Step4 RaceFinished→스코어링)는 핸들러 구현 + 프로바이더 등록만으로 붙는다.
 */
@Processor(QUEUE.DOMAIN_EVENTS)
export class DomainEventDispatcher extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(DomainEventDispatcher.name);
  private handlers: DomainEventHandler[] = [];

  constructor(private readonly discovery: DiscoveryService) {
    super();
  }

  onModuleInit(): void {
    this.handlers = this.discovery
      .getProviders()
      .map((wrapper) => wrapper.instance)
      .filter((instance): instance is DomainEventHandler => instance instanceof DomainEventHandler);
    this.logger.log(`도메인 이벤트 핸들러 ${this.handlers.length}개 등록됨`);
  }

  async process(job: Job): Promise<void> {
    const data = (job.data ?? {}) as Record<string, unknown>;

    // 매칭되는 모든 핸들러에 팬아웃. **핸들러마다 별도 ALS 스토어**(runWithContext)에서 실행한다 —
    // 워커 경계라 스토어가 없으므로 각 호출이 새 Map을 열고, 동시 팬아웃에도 @Transactional의
    // ENTITY_MANAGER/DDD_EVENTS 슬롯이 핸들러 간 교차오염되지 않는다. 개별 예외도 격리(다른 핸들러·잡에 전파 안 됨).
    await Promise.all(
      this.handlers
        .filter((handler) => handler.supports(job.name))
        .map((handler) =>
          runWithContext(async () => {
            try {
              await handler.handle(job.name, data);
            } catch (error) {
              this.logger.error(
                `핸들러(${handler.constructor.name}) 처리 실패 (event=${job.name}): ${(error as Error).message}`,
                (error as Error).stack
              );
            }
          })
        )
    );
  }
}
