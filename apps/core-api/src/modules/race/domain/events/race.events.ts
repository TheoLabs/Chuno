import { DddEvent } from '@libs/ddd';

/**
 * Race 도메인 이벤트 (S3-3/S3-6) — 경주 진행/종료를 표현. `DddEvent`를 상속해 수집/발행 파이프라인 재사용.
 *
 * - `publishEvent()`로 애그리거트에 수집 → 커밋 후 인프로세스(BullMQ `domain-events` 큐)로 발행.
 * - `DomainEventDispatcher`가 팬아웃 → `RaceBroadcastHandler`가 '/race' 네임스페이스로 브로드캐스트.
 * - payload는 `roomId`(브로드캐스트 라우팅 키) + 도메인 식별자. 엔티티 배열엔 등록하지 않는다(전이 객체).
 *
 * NOTE: 이벤트는 Race가 영속되기 전(publishEvent 시점)에 만들어질 수 있어 raceId가 아직 없을 수 있다 —
 * 브로드캐스트/소비는 항상 안정적인 `roomId`를 키로 쓴다.
 */

/** 경주 출발(RoomLive → Race 생성, S3-3). 전원 동시 출발(startedAt) 동기화용. */
export class RaceStarted extends DddEvent {
  constructor(
    public readonly roomId: number,
    public readonly startedAt: number, // epoch millis(서버 권위 시각)
    public readonly targetDistance: number,
    public readonly limitMinutes: number
  ) {
    super();
  }
}

/** 러너 완주(distance ≥ 목표거리, S3-6). '/race' → `runnerFinished`. */
export class RunnerFinished extends DddEvent {
  constructor(
    public readonly roomId: number,
    public readonly userId: number,
    public readonly finishedAt: number // epoch millis
  ) {
    super();
  }
}

/** 경주 종료(전원 완주 OR 제한시간 경과, S3-6). '/race' → `raceFinished`. */
export class RaceFinished extends DddEvent {
  constructor(public readonly roomId: number) {
    super();
  }
}
