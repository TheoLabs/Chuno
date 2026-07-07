import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { DddEvent, DomainEventPublisher } from '@libs/ddd';
import { QUEUE } from './queue.constants';

/**
 * `DomainEventPublisher` 포트의 BullMQ 구현 — 이벤트를 `domain-events` 큐로 인큐한다.
 *
 * 잡 이름 = 이벤트 클래스명(`ParticipantJoined` 등), 잡 데이터 = 직렬화된 페이로드.
 * 소비자(로비 게이트웨이 워커, S2-4)는 잡 이름으로 라우팅해 브로드캐스트한다.
 */
@Injectable()
export class BullDomainEventPublisher extends DomainEventPublisher {
  constructor(@InjectQueue(QUEUE.DOMAIN_EVENTS) private readonly queue: Queue) {
    super();
  }

  async publish(events: DddEvent[]): Promise<void> {
    await Promise.all(
      events.map((event) =>
        this.queue.add(event.constructor.name, this.toJobData(event), {
          removeOnComplete: true,
          removeOnFail: 100,
        })
      )
    );
  }

  /** 엔티티 잡음(id·traceId·outbox 컬럼)을 걷어내고 도메인 필드 + eventType·occurredAt만 남긴다. */
  private toJobData(event: DddEvent): Record<string, unknown> {
    const { id, traceId, eventType, payload, eventStatus, scheduledAt, createdAt, updatedAt, occurredAt, ...fields } =
      event as unknown as Record<string, unknown>;
    return { eventType: event.constructor.name, occurredAt, ...fields };
  }
}
