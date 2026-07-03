import { Module } from '@nestjs/common';
import { UserRepository } from './infrastructure/user.repository';
import { GeneralUserController } from './presentation/general-user.controller';
import { GeneralUserService } from './applications/general-user.service';
import { LegalDocumentModule } from '@modules/legal-document/legal-document.module';

@Module({
  imports: [LegalDocumentModule],
  controllers: [GeneralUserController],
  providers: [UserRepository, GeneralUserService],
  exports: [UserRepository],
})
export class UserModule {}
