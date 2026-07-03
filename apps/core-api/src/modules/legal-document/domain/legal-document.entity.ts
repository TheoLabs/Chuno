import { today } from '@libs/date';
import { DddAggregate } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { BadRequestException } from '@nestjs/common';
import { Column, Entity, PrimaryGeneratedColumn, Unique } from 'typeorm';

export enum LegalDocumentType {
  TERMS_OF_SERVICE = 'terms-of-service',
  PRIVACY_POLICY = 'privacy-policy',
  LOCATION_SERVICE = 'location-service',
  MARKETING = 'marketing',
}

export enum LegalDocumentStatus {
  DRAFT = 'draft',
  ACTIVE = 'active',
  ARCHIVED = 'archived',
}

type Ctor = {
  type: LegalDocumentType;
  version: string;
  title: string;
  content: string;
  isRequired: boolean;
  expectedActivateOn: CalendarDate;
};

@Entity()
@Unique('legal_document_type_version_unique', ['type', 'version'])
export class LegalDocument extends DddAggregate {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ type: 'enum', enum: LegalDocumentType })
  type: LegalDocumentType;

  @Column()
  version: string;

  @Column()
  title: string;

  @Column({ type: 'text' })
  content: string;

  @Column()
  expectedActivateOn: CalendarDate;

  @Column()
  isRequired: boolean;

  @Column({ type: 'enum', enum: LegalDocumentStatus })
  status: LegalDocumentStatus;

  private constructor(args: Ctor) {
    super();

    if (args) {
      this.type = args.type;
      this.version = args.version;
      this.title = args.title;
      this.content = args.content;
      this.expectedActivateOn = args.expectedActivateOn;
      this.status = LegalDocumentStatus.DRAFT;
      this.isRequired = args.isRequired;
    }
  }

  static of(args: Ctor) {
    if (args.expectedActivateOn <= today('YYYY-MM-DD')) {
      throw new BadRequestException('활성 예정 시각은 오늘보다 이후여야 합니다.', {
        description: '활성 예정 시각은 오늘보다 이후여야 합니다.',
      });
    }

    return new LegalDocument(args);
  }

  activate() {
    if (this.status !== LegalDocumentStatus.DRAFT) {
      throw new BadRequestException('초안 상태인 경우에만 활성화할 수 있습니다.', {
        description: '초안 상태인 경우에만 활성화할 수 있습니다.',
      });
    }

    this.status = LegalDocumentStatus.ACTIVE;
  }

  archive() {
    if (this.status !== LegalDocumentStatus.ACTIVE) {
      throw new BadRequestException('활성 상태인 경우에만 비활성화할 수 있습니다.', {
        description: '활성 상태인 경우에만 비활성화할 수 있습니다.',
      });
    }

    this.status = LegalDocumentStatus.ARCHIVED;
  }

  static getRequiredLegalDocumentTypes() {
    return [LegalDocumentType.TERMS_OF_SERVICE, LegalDocumentType.PRIVACY_POLICY, LegalDocumentType.LOCATION_SERVICE];
  }
}
