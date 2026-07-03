import { GeneralLegalDocumentService } from '@modules/legal-document/applications/general-legal-document.service';
import { LegalDocumentRepository } from '@modules/legal-document/infrastructure/legal-document.repository';
import { GeneralLegalDocumentController } from '@modules/legal-document/presentation/general-legal-document.controller';
import { Module } from '@nestjs/common';

@Module({
  imports: [],
  controllers: [GeneralLegalDocumentController],
  providers: [LegalDocumentRepository, GeneralLegalDocumentService],
  exports: [LegalDocumentRepository],
})
export class LegalDocumentModule {}
