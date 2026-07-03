import { DddService } from '@libs/ddd';
import { PaginationOptions } from '@libs/utils';
import { LegalDocumentStatus, LegalDocumentType } from '@modules/legal-document/domain/legal-document.entity';
import { LegalDocumentRepository } from '@modules/legal-document/infrastructure/legal-document.repository';
import {
  GeneralLegalDocumentDetailResponseDto,
  GeneralLegalDocumentListResponseDto,
} from '@modules/legal-document/presentation/dto';
import { Injectable, NotFoundException } from '@nestjs/common';

@Injectable()
export class GeneralLegalDocumentService extends DddService {
  constructor(private readonly legalDocumentRepository: LegalDocumentRepository) {
    super();
  }

  async list({ types }: { types?: LegalDocumentType[] }, options: PaginationOptions) {
    const [legalDocuments, total] = await Promise.all([
      this.legalDocumentRepository.find({ statuses: [LegalDocumentStatus.ACTIVE], types }, { options }),
      this.legalDocumentRepository.count({ statuses: [LegalDocumentStatus.ACTIVE], types }),
    ]);

    console.log('hi');

    return {
      items: legalDocuments.map((legalDocument) => legalDocument.toInstance(GeneralLegalDocumentListResponseDto)),
      total,
    };
  }

  async retrieve({ id }: { id: number }) {
    const [legalDocument] = await this.legalDocumentRepository.find({
      ids: [id],
      statuses: [LegalDocumentStatus.ACTIVE],
    });

    if (!legalDocument) {
      throw new NotFoundException('존재하지 않는 약관입니다.', {
        description: '존재하지 않는 약관입니다.',
      });
    }

    return legalDocument.toInstance(GeneralLegalDocumentDetailResponseDto);
  }
}
