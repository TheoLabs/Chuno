import { DddAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { Column, Entity, OneToMany, OneToOne, PrimaryGeneratedColumn } from 'typeorm';
import { AuthIdentity, AuthProvider } from './auth-identity.entity';
import { today } from '@libs/date';
import { UserConsent, UserConsentCtor } from './user-consent.entity';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { LegalDocument, LegalDocumentStatus } from '@modules/legal-document/domain/legal-document.entity';

export enum RunnerLevel {
  BEGINNER = 'beginner',
  INTERMEDIATE = 'intermediate',
  ADVANCED = 'advanced',
}

export enum RunnerTier {
  BRONZE = 'bronze',
  SILVER = 'silver',
  GOLD = 'gold',
  PLATINUM = 'platinum',
  DIAMOND = 'diamond',
}

type Ctor = {
  nickname: string;
  level: RunnerLevel;
  profileImageFileId?: number;
  bio?: string;
};

@Entity()
export class User extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'varchar', length: 20, unique: true, nullable: true })
  nickname: string | null;

  @Column({ type: 'enum', enum: RunnerLevel, nullable: true })
  level: RunnerLevel | null;

  @Column({ type: 'enum', enum: RunnerTier })
  tier: RunnerTier;

  @Column({ type: 'int', nullable: true })
  profileImageFileId: number | null;

  @Column({ type: 'varchar', length: 400, nullable: true })
  bio: string | null;

  @Column()
  joinOn: CalendarDate;

  @Column({ type: 'varchar', length: 30, nullable: true })
  onboardedOn: CalendarDate | null;

  @OneToOne(() => AuthIdentity, (authIdentity) => authIdentity.user, { cascade: true })
  authIdentity: AuthIdentity;

  @OneToMany(() => UserConsent, (userConsent) => userConsent.user, { cascade: true })
  consents: UserConsent[];

  private constructor(args?: Partial<Ctor>) {
    super();

    if (args) {
      this.nickname = args.nickname ?? null;
      this.level = args.level ?? null;
      this.profileImageFileId = args.profileImageFileId ?? null;
      this.bio = args.bio ?? null;
      this.tier = RunnerTier.BRONZE;
      this.joinOn = today();
      this.onboardedOn = null;
      this.consents = [];
    }
  }

  // 온보딩까지 마친 유저 생성(닉네임·레벨·동의 포함).
  static of(args: Ctor & { provider: AuthProvider; sub: string } & { consents: UserConsent[] }) {
    const user = new User(args);

    user.setAuthIdentity(args.provider, args.sub);
    args.consents.forEach((content) => user.addConsent(content));

    return user;
  }

  // 첫 소셜 로그인: 온보딩 전 유저 생성(nickname/level/onboardedOn = null).
  static createFromSocial(args: { provider: AuthProvider; sub: string }) {
    const user = new User({});

    user.setAuthIdentity(args.provider, args.sub);

    return user;
  }

  setAuthIdentity(provider: AuthProvider, sub: string) {
    this.authIdentity = AuthIdentity.of({ provider, sub });
  }

  addConsent(consentCtor: UserConsentCtor) {
    const consent = UserConsent.of(consentCtor);

    this.consents.push(consent);
  }

  onboard({
    nickname,
    level,
    legalDocuments,
  }: {
    nickname: string;
    level: RunnerLevel;
    legalDocuments: LegalDocument[];
  }) {
    if (!legalDocuments.every((legalDocument) => legalDocument.status === LegalDocumentStatus.ACTIVE)) {
      throw new BadRequestException('모든 약관은 유효해야 합니다.', {
        description: '모든 약관은 유효해야 합니다.',
      });
    }

    if (this.onboardedOn) {
      throw new ConflictException('이미 온보딩된 유저입니다.', { description: '이미 설정이 완료되었습니다.' });
    }

    const requiredLegalDocumentTypes = LegalDocument.getRequiredLegalDocumentTypes();

    const provided = new Set(legalDocuments.map((c) => c.type));
    const missing = requiredLegalDocumentTypes.filter((t) => !provided.has(t));
    if (missing.length > 0) {
      throw new BadRequestException(`필수 동의 누락: ${missing.join(', ')}`, {
        description: '필수 동의 항목이 체크해야합니다.',
      });
    }

    this.nickname = nickname;
    this.level = level;
    this.onboardedOn = today('YYYY-MM-DD HH:mm:ss');

    legalDocuments.forEach((legalDocument) =>
      this.addConsent({
        legalDocumentId: legalDocument.id,
        type: legalDocument.type,
        documentVersion: legalDocument.version,
      })
    );
  }
}
