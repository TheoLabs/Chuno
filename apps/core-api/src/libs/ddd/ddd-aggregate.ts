import { DddBaseAggregate } from './ddd-base-aggregate';
import { DddEvent } from './ddd-event';

/**
 * 애그리게이트 루트. 공통 베이스({@link DddBaseAggregate})에 **도메인 이벤트**를 더한다.
 * 루트만 이벤트를 발행/보관한다. 루트가 아닌 owned child 는 DddBaseAggregate 를 직접 상속한다.
 */
export abstract class DddAggregate extends DddBaseAggregate {
  private events: DddEvent[] = [];

  publishEvent(event: DddEvent) {
    this.events.push(event);
  }

  getPublishedEvents() {
    return [...this.events];
  }
}
