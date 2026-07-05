import { Module } from '@nestjs/common';
import { UserModule } from './user/user.module';
import { AuthModule } from './auth/auth.module';
import { LegalDocumentModule } from '@modules/legal-document/legal-document.module';
import { RoomModule } from '@modules/room/room.module';

@Module({
  imports: [UserModule, AuthModule, LegalDocumentModule, RoomModule],
  exports: [UserModule, AuthModule, LegalDocumentModule, RoomModule],
})
export class DomainModule {}
