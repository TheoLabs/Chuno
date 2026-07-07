import { DddEvent } from './ddd-event';

/**
 * 인프로세스 도메인 이벤트 발행 포트(추상 클래스 = 인터페이스 + DI 토큰).
 *
 * `@Transactional`이 **커밋 성공 후** 애그리거트가 발행한 이벤트를 이 포트로 흘려보낸다.
 * 도메인/애플리케이션은 구현(BullMQ)을 모른 채 이 포트에만 의존한다(테스트 목·구현 교체 용이).
 *
 * 구현: `BullDomainEventPublisher`(libs/queue) — `domain-events` 큐로 인큐. 아웃박스→Kafka(크로스서비스)와 별개.
 */
export abstract class DomainEventPublisher {
  /** 수집된 도메인 이벤트들을 인프로세스로 발행한다(커밋 후 호출). */
  abstract publish(events: DddEvent[]): Promise<void>;
}
