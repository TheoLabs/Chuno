import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { AuthService } from '../application/auth.service';
import { LogoutDto, RefreshDto, SocialLoginDto } from './dto/auth.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // 소셜 로그인 → 액세스+리프레시 발급.
  @Post('social-login')
  @HttpCode(200)
  socialLogin(@Body() dto: SocialLoginDto) {
    return this.authService.loginWithSocial(dto.provider, dto.token);
  }

  // 리프레시 회전. 재사용 감지 시 401 + 계열 무효화.
  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() dto: RefreshDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  // 로그아웃 — 제시된 리프레시의 계열 전체 폐기.
  @Post('logout')
  @HttpCode(200)
  async logout(@Body() dto: LogoutDto) {
    await this.authService.logout(dto.refreshToken);
    return { success: true };
  }
}
