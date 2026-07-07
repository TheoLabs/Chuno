import { DddEvent } from '@libs/ddd';

/**
 * Room 도메인 이벤트 (S2-5) — 방 상태 변화를 표현. `DddEvent`를 상속해 기존 수집/발행 파이프라인을 재사용한다.
 *
 * - `publishEvent()`로 애그리거트에 수집되고, 커밋 후 **인프로세스(BullMQ `domain-events` 큐)** 로 발행된다.
 * - 로비 게이트웨이(S2-4)가 구독해 같은 방 클라이언트에 브로드캐스트한다.
 * - payload는 `roomId` + 식별자(발생시각 `occurredAt`은 `DddEvent`가 자동 세팅).
 *
 * NOTE: 엔티티 배열(`databases/typeorm/entities.ts`)에 등록하지 않으므로 별도 테이블로 잡히지 않는다(전이 객체).
 */

/** 방 생성됨. (정의만 — MVP 인프로세스 소비자 없음: 홈 목록은 폴링. 실시간 홈 피드 도입 시 발행) */
export class RoomCreated extends DddEvent {
  constructor(
    public readonly roomId: number,
    public readonly hostUserId: number
  ) {
    super();
  }
}

/** 참가자 입장. 로비 → `participantJoined` 브로드캐스트. */
export class ParticipantJoined extends DddEvent {
  constructor(
    public readonly roomId: number,
    public readonly userId: number
  ) {
    super();
  }
}

/** 참가자 이탈. 로비 → `participantLeft` 브로드캐스트. */
export class ParticipantLeft extends DddEvent {
  constructor(
    public readonly roomId: number,
    public readonly userId: number
  ) {
    super();
  }
}

/** 방 곧 시작(참여 마감, `scheduledStartOn − 10s`). 예약 스케줄러(S2-3)가 발행 → 로비 `roomStatusChanged`. */
export class RoomStarting extends DddEvent {
  constructor(public readonly roomId: number) {
    super();
  }
}

/** 방 출발(STARTING→LIVE, `scheduledStartOn` 정각). 예약 스케줄러(S2-3) 발행 → 로비 `roomStatusChanged(live)`, Step3가 Race 생성(S3-3). */
export class RoomLive extends DddEvent {
  constructor(public readonly roomId: number) {
    super();
  }
}

/** 방 취소됨(방장 취소/호스트 이탈). 로비 → `roomCancelled`(안내 후 홈 복귀). */
export class RoomCancelled extends DddEvent {
  constructor(
    public readonly roomId: number,
    public readonly hostUserId: number
  ) {
    super();
  }
}
