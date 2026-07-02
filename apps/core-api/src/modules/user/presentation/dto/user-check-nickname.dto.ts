import { IsNotEmpty, IsString, Length } from 'class-validator';

export class UserCheckNicknameQueryDto {
  @IsString()
  @Length(2, 12, { message: '닉네임은 2글자 이상 12글자 이내여야 합니다.' })
  @IsNotEmpty()
  nickname: string;
}
