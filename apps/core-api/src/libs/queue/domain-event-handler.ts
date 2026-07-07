/**
 * 인프로세스 도메인 이벤트 핸들러 포트(추상 클래스 = 인터페이스 + 타입 태그).
 *
 * `domain-events` 큐의 단일 워커(`DomainEventDispatcher`)가 등록된 모든 핸들러를 팬아웃해,
 * `supports(eventName)`가 참인 핸들러에 `handle`을 위임한다. 각 핸들러 예외는 서로 격리된다.
 *
 * 왜 팬아웃인가: BullMQ 잡은 큐의 워커 **한 곳**에만 배달된다. `@Processor(domain-events)`를
 * 여러 개 두면 같은 이벤트가 그중 하나에만 가 깨진다. 그래서 워커는 하나(디스패처)로 두고,
 * 소비는 이 핸들러들을 인프로세스로 팬아웃한다. 새 소비자는 이 포트 구현체 + 프로바이더 등록만으로 확장된다.
 *
 * 구현체는 각 도메인 모듈이 **일반 프로바이더로 등록**한다(디스패처가 DiscoveryService로 수집).
 */
export abstract class DomainEventHandler {
  /** 이 핸들러가 처리하는 이벤트 이름(잡 이름 = 이벤트 클래스명)인지 판별. */
  abstract supports(eventName: string): boolean;

  /** 이벤트 처리. `data`는 발행 시 직렬화된 페이로드(roomId 등 도메인 필드). */
  abstract handle(eventName: string, data: Record<string, unknown>): Promise<void>;
}
