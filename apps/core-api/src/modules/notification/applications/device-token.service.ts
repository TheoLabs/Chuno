import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { Injectable } from '@nestjs/common';
import { DeviceToken, DevicePlatform } from '@modules/notification/domain/device-token.entity';
import { DeviceTokenRepository } from '@modules/notification/infrastructure/device-token.repository';

/**
 * 기기 토큰 등록/정리 서비스 (S5-1).
 *
 * register: token 유니크 upsert — 이미 있으면 소유 유저/플랫폼을 갱신(재귀속), 없으면 신규 저장. 멱등.
 * unregister: 로그아웃 정리 — 해당 유저 소유의 토큰만 제거.
 */
@Injectable()
export class DeviceTokenService extends DddService {
  constructor(private readonly deviceTokenRepository: DeviceTokenRepository) {
    super();
  }

  @Transactional()
  async register({ userId, token, platform }: { userId: number; token: string; platform: DevicePlatform }): Promise<DeviceToken> {
    const [existing] = await this.deviceTokenRepository.find({ token });
    if (existing) {
      existing.reassign({ userId, platform });
      await this.deviceTokenRepository.save([existing]);
      return existing;
    }

    const created = DeviceToken.of({ userId, token, platform });
    await this.deviceTokenRepository.save([created]);
    return created;
  }

  @Transactional()
  async unregister({ userId, token }: { userId: number; token: string }): Promise<void> {
    const [existing] = await this.deviceTokenRepository.find({ token });
    // 소유자 불일치/미존재는 무시(멱등) — 남의 토큰을 지우지 않는다.
    if (!existing || existing.userId !== userId) return;
    await this.deviceTokenRepository.remove([existing]);
  }
}
