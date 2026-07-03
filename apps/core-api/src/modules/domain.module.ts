import { Module } from '@nestjs/common';
import { UserModule } from './user/user.module';
import { AuthModule } from './auth/auth.module';
import { LegalDocumentModule } from '@modules/legal-document/legal-document.module';

@Module({
  imports: [UserModule, AuthModule, LegalDocumentModule],
  exports: [UserModule, AuthModule, LegalDocumentModule],
})
export class DomainModule {}
