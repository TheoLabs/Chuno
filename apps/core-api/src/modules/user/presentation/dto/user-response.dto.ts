import { RunnerLevel, RunnerTier } from '@modules/user/domain/user.entity';
import { Exclude, Expose } from 'class-transformer';

@Exclude()
abstract class BaseUserResponseDto {
  @Expose()
  id: number;

  @Expose()
  nickname: string | null;

  @Expose()
  level: RunnerLevel | null;

  @Expose()
  tier: RunnerTier | null;

  @Expose()
  profileImageFileId: number | null;

  @Expose()
  bio: string | null;

  @Expose()
  onboardedOn: string | null;
}

@Exclude()
export class GeneralUserResponseDto extends BaseUserResponseDto {}
