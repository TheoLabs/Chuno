import { DddAggregate } from '@libs/ddd';
import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/** 알림 종류 — 타 컨텍스트 이벤트를 구독해 생성. */
export enum NotiType {
  RACE_STARTING = 'RACE_STARTING', // 경주 임박(RoomStarting)
  PARTICIPANT_JOINED = 'PARTICIPANT_JOINED', // 새 참가자 입장(ParticipantJoined)
  RESULT_READY = 'RESULT_READY', // 결과 도착(RaceFinished)
}

type CreateArgs = {
  userId: number;
  type: NotiType;
  payload: Record<string, unknown>;
  dedupeKey: string;
  sentAt: Date;
};

/**
 * Notification 프로젝션 (S5-1) — 타 컨텍스트 이벤트를 구독해 생성되는 알림 발송 기록(순수 소비자).
 *
 * DomainEventHandler(ParticipantJoined·RoomStarting·RaceFinished)가 대상 유저별로 1건씩 저장한다.
 * `dedupeKey`(유니크) = `type:room:{roomId}:user:{userId}` 조합으로 중복 이벤트에도 1건만 남아 멱등.
 * `sentAt`은 발송 시각(자동 감사 UTC/Date).
 */
@Entity()
@Index('idx_notification_dedupe', ['dedupeKey'], { unique: true })
@Index('idx_notification_user', ['userId'])
export class Notification extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ comment: '수신 user Id' })
  userId: number;

  @Column({ type: 'enum', enum: NotiType, comment: '알림 종류' })
  type: NotiType;

  @Column({ type: 'json', comment: '알림 페이로드(roomId 등)' })
  payload: Record<string, unknown>;

  @Column({ comment: '멱등 키(type:room:{roomId}:user:{userId}) — 중복 이벤트 방어' })
  dedupeKey: string;

  @Column({ type: 'datetime', comment: '발송 시각(서버 UTC)' })
  sentAt: Date;

  private constructor(args: CreateArgs) {
    super();

    if (args) {
      this.userId = args.userId;
      this.type = args.type;
      this.payload = args.payload;
      this.dedupeKey = args.dedupeKey;
      this.sentAt = args.sentAt;
    }
  }

  static of(args: CreateArgs): Notification {
    return new Notification(args);
  }
}
