import { Body, Controller, Delete, Post, UseGuards } from '@nestjs/common';
import { Context, ContextKey } from '@libs/context';
import { UserGuard } from '@libs/guards';
import { User } from '@modules/user/domain/user.entity';
import { DeviceTokenService } from '@modules/notification/applications/device-token.service';
import { RegisterDeviceTokenDto, UnregisterDeviceTokenDto } from '@modules/notification/presentation/dto';

/**
 * 기기 토큰 API (S5-1) — 인증 필요. 푸시 발송 대상 토큰 등록/해제.
 * - `POST   /users/me/device-tokens` : 등록(유저별 upsert, 중복 토큰 갱신). 단건 { data: {...} }.
 * - `DELETE /users/me/device-tokens` : 해제(로그아웃 정리). { data: {} }.
 */
@Controller('users')
@UseGuards(UserGuard)
export class DeviceTokenController {
  constructor(
    private readonly deviceTokenService: DeviceTokenService,
    private readonly context: Context
  ) {}

  @Post('me/device-tokens')
  async register(@Body() body: RegisterDeviceTokenDto) {
    const user = this.context.get<User>(ContextKey.USER);
    const deviceToken = await this.deviceTokenService.register({
      userId: user.id,
      token: body.token,
      platform: body.platform,
    });
    return { data: { id: deviceToken.id, platform: deviceToken.platform } };
  }

  @Delete('me/device-tokens')
  async unregister(@Body() body: UnregisterDeviceTokenDto) {
    const user = this.context.get<User>(ContextKey.USER);
    await this.deviceTokenService.unregister({ userId: user.id, token: body.token });
    return { data: {} };
  }
}
