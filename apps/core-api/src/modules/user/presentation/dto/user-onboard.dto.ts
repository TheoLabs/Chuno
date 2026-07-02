import { UserConsentType } from '@modules/user/domain/user-consent.entity';
import { RunnerLevel } from '@modules/user/domain/user.entity';
import { Type } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsEnum, IsNotEmpty, IsString, Length, ValidateNested } from 'class-validator';

class ConsentDto {
  @IsEnum(UserConsentType)
  type: UserConsentType;

  @IsString()
  @IsNotEmpty()
  documentVersion: string;
}

export class GeneralUserOnboardDto {
  @IsNotEmpty()
  @Length(2, 12)
  nickname: string;

  @IsEnum(RunnerLevel)
  level: RunnerLevel;

  @ValidateNested({ each: true })
  @Type(() => ConsentDto)
  @IsArray()
  @ArrayNotEmpty()
  consents: ConsentDto[];
}
