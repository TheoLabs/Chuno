/**
 * BullMQ 큐 이름 상수 — 단일 진실 소스.
 *
 * - `ROOM_SCHEDULER`: 방 예약 지연잡(STARTING 전환 = `scheduledStartOn − 10s` 등, S2-3).
 * - `RACE_SCHEDULER`: 경주 제한시간 만료 지연잡(`startedAt + limitMinutes` 시점 finalize, S3-6).
 * - `DOMAIN_EVENTS`: 인프로세스 도메인 이벤트 디스패치(S2-5 → 팬아웃 핸들러들: 로비 브로드캐스트·Race 생성 등).
 *
 * 이벤트/지연잡 모두 **인프로세스**(core-api 내부) 처리다. 아웃박스→Kafka(크로스서비스 durable)와는 별개.
 */
export const QUEUE = {
  ROOM_SCHEDULER: 'room-scheduler',
  RACE_SCHEDULER: 'race-scheduler',
  DOMAIN_EVENTS: 'domain-events',
} as const;

export type QueueName = (typeof QUEUE)[keyof typeof QUEUE];
