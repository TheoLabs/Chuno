import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

export enum DddEventStatus {
  PENDING = 'pending',
  PROCESSED = 'processed',
  FAILED = 'failed',
}

@Entity('ddd_events')
@Index(['eventStatus', 'createdAt'])
export class DddEvent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  traceId!: string;

  @Column({ comment: '이벤트의 타입' })
  eventType!: string;

  @Column({ type: 'text' })
  payload!: string;

  @Column({ type: 'enum', enum: DddEventStatus, default: DddEventStatus.PENDING })
  eventStatus: DddEventStatus;

  @Column({ comment: '실행 예정 시각', nullable: true })
  scheduledAt?: Date;

  @Column()
  private occurredAt!: Date;

  @CreateDateColumn()
  private readonly createdAt!: Date;

  @UpdateDateColumn()
  private readonly updatedAt!: Date;

  constructor() {
    this.eventType = this.constructor.name;
    this.occurredAt = new Date();
  }

  static fromEvent(event: DddEvent) {
    const dddEvent = new DddEvent();
    const { occurredAt, eventType, ...payload } = event;
    dddEvent.eventType = event.constructor.name;
    dddEvent.payload = JSON.stringify(payload);
    return dddEvent;
  }

  setTraceId(traceId: string) {
    this.traceId = traceId;
  }
}
