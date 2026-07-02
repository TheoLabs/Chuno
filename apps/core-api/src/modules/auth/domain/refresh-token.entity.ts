import { DddAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/**
 * 회전형(rotating) 리프레시 토큰 — opaque 토큰의 sha256 해시만 저장한다(원문 미저장).
 * 같은 계열(familyId)로 회전 이력을 잇고, 이미 회전/폐기된 토큰이 다시 제시되면
 * 재사용 공격으로 보고 계열 전체를 무효화한다.
 */
@Entity()
export class RefreshToken extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  userId: number;

  // opaque 리프레시 토큰의 sha256(hex, 64자). 조회 키.
  @Column({ type: 'varchar', length: 64, unique: true })
  tokenHash: string;

  // 회전 계열 식별자. 최초 로그인에 새로 발급, 회전 시 승계.
  @Index()
  @Column({ type: 'varchar', length: 36 })
  familyId: string;

  // 이 토큰이 회전되어 후속 토큰이 발급되었는지.
  @Column({ type: 'boolean', default: false })
  rotated: boolean;

  // 계열 무효화/로그아웃으로 폐기되었는지.
  @Column({ type: 'boolean', default: false })
  revoked: boolean;

  // 만료 시각(KST). 비즈니스 날짜라 CalendarDate + xxxOn.
  @Column({ type: 'varchar', length: 30 })
  expiresOn: CalendarDate;

  private constructor(args?: { userId: number; tokenHash: string; familyId: string; expiresOn: CalendarDate }) {
    super();

    if (args) {
      this.userId = args.userId;
      this.tokenHash = args.tokenHash;
      this.familyId = args.familyId;
      this.expiresOn = args.expiresOn;
      this.rotated = false;
      this.revoked = false;
    }
  }

  static issue(args: { userId: number; tokenHash: string; familyId: string; expiresOn: CalendarDate }) {
    return new RefreshToken(args);
  }

  markRotated() {
    this.rotated = true;
  }

  markRevoked() {
    this.revoked = true;
  }

  // 회전에 쓸 수 있는 살아있는 토큰인지(회전·폐기 안 됨).
  get isUsable() {
    return !this.rotated && !this.revoked;
  }
}
