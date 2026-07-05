import { today } from '@libs/date';
import { DddAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { Participant } from '@modules/room/domain/participant.entity';
import { BadRequestException } from '@nestjs/common';
import { Column, Entity, Index, OneToMany, PrimaryGeneratedColumn } from 'typeorm';

export enum RoomStatus {
  RECRUITING = 'recruiting',
  STARTING = 'starting', // NOTE: 방 참여 마감을 위해 scheduledStartOn - 10초 기준의 상태
  LIVE = 'live',
  FINISHED = 'finished',
  CANCELLED = 'cancelled',
}

type Ctor = {
  hostUserId: number;
  name: string;
  targetDistance: number;
  limitMinutes: number;
  maxParticipants: number;
  scheduledStartOn: CalendarDate;
  participant: Participant;
};

@Entity()
@Index('idx_room_host_user_id', ['hostUserId'])
export class Room extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ comment: '방장 user Id' })
  hostUserId: number;

  @Column({ comment: '방 이름' })
  name: string;

  @Column({ comment: '목표거리' })
  targetDistance: number;

  @Column({ comment: '목표 시간대(분)' })
  limitMinutes: number;

  @Column({ comment: '최대 참여 인원' })
  maxParticipants: number;

  @Column({ comment: '경기 시작 시간' })
  scheduledStartOn: CalendarDate;

  @Column({ type: 'enum', enum: RoomStatus })
  status: RoomStatus;

  @OneToMany(() => Participant, (participant) => participant.room, { cascade: true, orphanedRowAction: 'delete' })
  participants: Participant[];

  private constructor(args: Ctor) {
    super();

    if (args) {
      this.hostUserId = args.hostUserId;
      this.name = args.name;
      this.targetDistance = args.targetDistance;
      this.limitMinutes = args.limitMinutes;
      this.maxParticipants = args.maxParticipants;
      this.scheduledStartOn = args.scheduledStartOn;
      this.status = RoomStatus.RECRUITING;
      this.participants = [];
    }
  }

  static of(args: Ctor) {
    if (args.scheduledStartOn <= today('YYYY-MM-DD HH:mm:ss')) {
      throw new BadRequestException('경기 시작 시간은 현재보다 과거일 수 없습니다.', {
        description: '경기 시작 시간은 현재보다 과거일 수 없습니다.',
      });
    }

    if (args.maxParticipants < 2) {
      throw new BadRequestException('최대 인원은 2명 이상이어야 합니다.', {
        description: '최대 인원은 2명 이상이어야 합니다.',
      });
    }

    if (args.limitMinutes < 10) {
      throw new BadRequestException('최소 운동 시간은 10분 이상이어야 합니다.', {
        description: '최소 운동 시간은 10분 이상이어야 합니다.',
      });
    }

    if (args.targetDistance < 1) {
      throw new BadRequestException('최소 목표 거리는 1km 이상이어야 합니다.', {
        description: '최소 목표 거리는 1km 이상이어야 합니다.',
      });
    }

    const room = new Room(args);

    room.addParticipant(args.participant);

    return room;
  }

  join({ userId }: { userId: number }) {
    if (this.status !== RoomStatus.RECRUITING) {
      throw new BadRequestException('모집중인 방만 참여할 수 있습니다.', {
        description: '모집중인 방만 참여할 수 있습니다.',
      });
    }

    if (this.participants.some((participant) => participant.userId === userId)) {
      throw new BadRequestException('이미 참여 중인 방입니다.', { description: '이미 참여 중인 방입니다.' });
    }

    this.addParticipant(Participant.of({ userId, isHost: false }));
  }

  leave({ userId }: { userId: number }) {
    if (this.status !== RoomStatus.RECRUITING) {
      throw new BadRequestException('경주 전인 방에서만 나갈 수 있습니다.', {
        description: '경주 전인 방에서만 나갈 수 있습니다.',
      });
    }

    const participant = this.participants.find((p) => p.userId === userId);

    if (!participant) {
      throw new BadRequestException('방에 참여 중이지 않습니다.', { description: '방에 참여 중이지 않습니다.' });
    }

    if (participant.isHost) {
      this.cancel();
      return;
    }

    this.participants = this.participants.filter((p) => p.userId !== userId);
  }

  cancel() {
    if (this.status === RoomStatus.CANCELLED || this.status === RoomStatus.FINISHED) {
      return;
    }

    this.status = RoomStatus.CANCELLED;
  }

  private addParticipant(participant: Participant) {
    if (this.maxParticipants <= this.participants.length) {
      throw new BadRequestException('정원이 가득 차 방에 참여할 수 없습니다.', {
        description: '정원이 가득 차 방에 참여할 수 없습니다.',
      });
    }

    this.participants.push(participant);
  }
}
