import { Module } from '@nestjs/common';
import { UserModule } from './user/user.module';
import { AuthModule } from './auth/auth.module';
import { LegalDocumentModule } from '@modules/legal-document/legal-document.module';
import { RoomModule } from '@modules/room/room.module';
import { RaceModule } from '@modules/race/race.module';
import { ScoringModule } from '@modules/scoring/scoring.module';
import { DomainEventsModule } from '@modules/domain-events/domain-events.module';

@Module({
  imports: [UserModule, AuthModule, LegalDocumentModule, RoomModule, RaceModule, ScoringModule, DomainEventsModule],
  exports: [UserModule, AuthModule, LegalDocumentModule, RoomModule, RaceModule, ScoringModule],
})
export class DomainModule {}
