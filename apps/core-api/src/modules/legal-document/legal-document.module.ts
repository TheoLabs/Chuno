import { LegalDocumentRepository } from '@modules/legal-document/infrastructure/legal-document.repository';
import { Module } from '@nestjs/common';

@Module({
  imports: [],
  controllers: [],
  providers: [LegalDocumentRepository],
  exports: [LegalDocumentRepository],
})
export class LegalDocumentModule {}
