import { DddEvent } from '@libs/ddd';
import { AuthIdentity } from '@modules/user/domain/auth-identity.entity';
import { UserConsent } from '@modules/user/domain/user-consent.entity';
import { User } from '@modules/user/domain/user.entity';
import { RefreshToken } from '@modules/auth/domain/refresh-token.entity';

export default [DddEvent, User, AuthIdentity, UserConsent, RefreshToken];
