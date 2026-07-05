import { today } from '@libs/date';
import { DddBaseAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { Room } from '@modules/room/domain/room.entity';
import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';

type Ctor = {
  userId: number;
  isHost: boolean;
};

@Entity()
export class Participant extends DddBaseAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  roomId: number;

  @Column()
  userId: number;

  @Column()
  isHost: boolean;

  @Column()
  joinedOn: CalendarDate;

  @ManyToOne(() => Room, (room) => room.participants)
  @JoinColumn({ name: 'roomId' })
  room: Room;

  private constructor(args: Ctor) {
    super();

    if (args) {
      this.userId = args.userId;
      this.joinedOn = today('YYYY-MM-DD HH:mm:ss');
      this.isHost = args.isHost;
    }
  }

  static of(args: Ctor) {
    return new Participant(args);
  }
}
