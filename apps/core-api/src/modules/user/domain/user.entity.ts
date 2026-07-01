import { DddAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { Column, Entity, OneToOne, PrimaryGeneratedColumn } from 'typeorm';
import { AuthIdentity } from './auth-identity.entity';

@Entity()
export class User extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  nickname: string;

  @Column({ type: 'int', nullable: true })
  profileImageFileId: number | null;

  @Column()
  joinOn: CalendarDate;

  @OneToOne(() => AuthIdentity, (authIdentity) => authIdentity.user, { cascade: true })
  authIdentity: AuthIdentity;
}
