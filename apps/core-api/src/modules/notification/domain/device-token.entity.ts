import { DddAggregate } from '@libs/ddd';
import { Column, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

/** 기기 플랫폼 — FCM/APNs 발송 대상 구분. */
export enum DevicePlatform {
  IOS = 'ios',
  ANDROID = 'android',
}

type CreateArgs = {
  userId: number;
  token: string;
  platform: DevicePlatform;
};

/**
 * DeviceToken 애그리거트 (S5-1) — 푸시 발송 대상 기기 토큰. 유저당 여러 기기 가능.
 *
 * token 유니크 — 같은 기기 토큰은 1건만 존재한다(기기 1대 ↔ 토큰 1개). 재등록 시 소유 유저/플랫폼을 갱신(upsert)해
 * 로그아웃→타 계정 로그인 시 토큰이 새 유저로 재귀속되게 한다. 시각은 자동 감사 타임스탬프(createdAt/updatedAt/UTC)만.
 */
@Entity()
@Index('idx_device_token_token', ['token'], { unique: true })
@Index('idx_device_token_user', ['userId'])
export class DeviceToken extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ comment: '소유 user Id' })
  userId: number;

  @Column({ comment: 'FCM 등록 토큰(기기별 유니크)' })
  token: string;

  @Column({ type: 'enum', enum: DevicePlatform, comment: '기기 플랫폼(ios·android)' })
  platform: DevicePlatform;

  private constructor(args: CreateArgs) {
    super();

    if (args) {
      this.userId = args.userId;
      this.token = args.token;
      this.platform = args.platform;
    }
  }

  static of(args: CreateArgs): DeviceToken {
    return new DeviceToken(args);
  }

  /** 재등록(upsert) — 기존 토큰 레코드의 소유 유저/플랫폼을 갱신. */
  reassign(args: { userId: number; platform: DevicePlatform }): void {
    this.userId = args.userId;
    this.platform = args.platform;
  }
}
