import { RunnerLevel } from '@modules/user/domain/user.entity';
import { ArrayNotEmpty, IsArray, IsEnum, IsInt, IsNotEmpty, Length } from 'class-validator';

export class GeneralUserOnboardDto {
  @IsNotEmpty()
  @Length(2, 12)
  nickname: string;

  @IsEnum(RunnerLevel)
  level: RunnerLevel;

  @IsArray()
  @ArrayNotEmpty()
  @IsInt({ each: true })
  legalDocumentIds: number[];
}
