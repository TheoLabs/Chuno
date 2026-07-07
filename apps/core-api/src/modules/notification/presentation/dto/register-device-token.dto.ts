import { IsEnum, IsNotEmpty, IsString } from 'class-validator';
import { DevicePlatform } from '@modules/notification/domain/device-token.entity';

/** 기기 토큰 등록 요청 — FCM 토큰 + 플랫폼(ios·android). */
export class RegisterDeviceTokenDto {
  @IsString()
  @IsNotEmpty()
  token: string;

  @IsEnum(DevicePlatform)
  platform: DevicePlatform;
}

/** 기기 토큰 해제 요청(로그아웃 정리) — 대상 토큰. */
export class UnregisterDeviceTokenDto {
  @IsString()
  @IsNotEmpty()
  token: string;
}
