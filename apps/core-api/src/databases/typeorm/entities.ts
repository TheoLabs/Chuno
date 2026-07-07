import { DddEvent } from '@libs/ddd';
import { AuthIdentity } from '@modules/user/domain/auth-identity.entity';
import { UserConsent } from '@modules/user/domain/user-consent.entity';
import { User } from '@modules/user/domain/user.entity';
import { RefreshToken } from '@modules/auth/domain/refresh-token.entity';
import { LegalDocument } from '@modules/legal-document/domain/legal-document.entity';
import { Room } from '@modules/room/domain/room.entity';
import { Participant } from '@modules/room/domain/participant.entity';
import { Race } from '@modules/race/domain/race.entity';
import { RaceParticipant } from '@modules/race/domain/race-participant.entity';
import { RaceResult } from '@modules/scoring/domain/race-result.entity';
import { RunnerStats } from '@modules/scoring/domain/runner-stats.entity';
import { RaceStatApplied } from '@modules/scoring/domain/race-stat-applied.entity';

export default [
  DddEvent,
  User,
  AuthIdentity,
  UserConsent,
  RefreshToken,
  LegalDocument,
  Room,
  Participant,
  Race,
  RaceParticipant,
  RaceResult,
  RunnerStats,
  RaceStatApplied,
];
