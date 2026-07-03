import { DddBaseAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { Column, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { User } from './user.entity';
import { today } from '@libs/date';
import { LegalDocumentType } from '@modules/legal-document/domain/legal-document.entity';

export type UserConsentCtor = {
  legalDocumentId: number;
  type: LegalDocumentType;
  documentVersion: string;
};

@Entity()
export class UserConsent extends DddBaseAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  userId: number;

  @Column()
  legalDocumentId: number;

  @Column()
  type: LegalDocumentType;

  @Column()
  documentVersion: string;

  @Column()
  agreedOn: CalendarDate;

  @Column({ type: 'varchar', length: 100, nullable: true })
  revokeOn: CalendarDate | null;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  private constructor(args: UserConsentCtor) {
    super();

    if (args) {
      this.legalDocumentId = args.legalDocumentId;
      this.type = args.type;
      this.documentVersion = args.documentVersion;
      this.agreedOn = today('YYYY-MM-DD HH:mm:ss');
    }
  }

  static of(args: UserConsentCtor) {
    return new UserConsent(args);
  }

  revoke() {
    this.revokeOn = today('YYYY-MM-DD HH:mm:ss');
  }
}
