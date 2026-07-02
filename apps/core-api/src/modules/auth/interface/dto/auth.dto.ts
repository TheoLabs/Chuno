import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { AuthProvider } from '@modules/user/domain/auth-identity.entity';

export class SocialLoginDto {
  @IsEnum(AuthProvider)
  provider: AuthProvider;

  // provider idToken/accessToken. AUTH_DEV_MODE에선 "dev:<sub>:<email>".
  @IsString()
  @IsNotEmpty()
  token: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class LogoutDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}
