import { DddBaseAggregate } from '@libs/ddd';
import { Column, Entity, JoinColumn, OneToOne, PrimaryGeneratedColumn, Unique } from 'typeorm';
import { User } from './user.entity';

export enum AuthProvider {
  KAKAO = 'kakao',
  GOOGLE = 'google',
  APPLE = 'apple',
}

@Entity()
@Unique('idx_unique_auth_identity_provider_sub', ['provider', 'sub'])
export class AuthIdentity extends DddBaseAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  userId: number;

  @Column({ type: 'enum', enum: AuthProvider })
  provider: AuthProvider;

  // provider가 발급한 외부 소셜 고유 ID(Google/Apple sub, Kakao id). 로그인 조회 키.
  @Column()
  sub: string;

  @OneToOne(() => User, (user) => user.authIdentity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  private constructor(args: { provider: AuthProvider; sub: string }) {
    super();

    if (args) {
      this.provider = args.provider;
      this.sub = args.sub;
    }
  }

  static of(args: { provider: AuthProvider; sub: string }) {
    return new AuthIdentity(args);
  }
}
