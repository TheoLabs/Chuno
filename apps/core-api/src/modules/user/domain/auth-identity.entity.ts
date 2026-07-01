import { DddBaseAggregate } from '@libs/ddd';
import { Column, Entity, JoinColumn, OneToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from './user.entity';

export enum AuthProvider {
  KAKAO = 'kakao',
  GOOGLE = 'google',
  APPLE = 'apple',
}

@Entity()
export class AuthIdentity extends DddBaseAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  userId: number;

  @Column({ type: 'enum', enum: AuthProvider })
  provider: AuthProvider;

  @OneToOne(() => User, (user) => user.authIdentity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;
}
