import { DddService } from '@libs/ddd';
import { Transactional } from '@libs/decorators';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { Notification, NotiType } from '@modules/notification/domain/notification.entity';
import { NotificationRepository } from '@modules/notification/infrastructure/notification.repository';
import { DeviceTokenRepository } from '@modules/notification/infrastructure/device-token.repository';
import { PushSender } from '@modules/notification/applications/push-sender';

export type NotifyRequest = {
  userIds: number[];
  type: NotiType;
  roomId: number;
  title: string;
  body: string;
  payload: Record<string, unknown>;
};

/**
 * Notification 저장 트랜잭션 경계(멱등). NotificationService에서 분리해 푸시 I/O를 트랜잭션 밖에 둔다.
 * dedupeKey 유니크로 중복 이벤트를 막고, 이미 존재하는 대상은 반환에서 제외해 중복 푸시도 막는다.
 *
 * NOTE: NotificationService보다 **먼저** 선언한다 — 데코레이터 메타데이터(design:paramtypes)가 런타임에
 *       이 클래스를 참조하므로 뒤에 두면 TDZ(초기화 전 접근) 에러가 난다.
 */
@Injectable()
export class NotificationPersister extends DddService {
  constructor(private readonly notificationRepository: NotificationRepository) {
    super();
  }

  /** 미저장 대상만 저장하고, 실제로 새로 저장한 userId 목록을 반환. */
  @Transactional()
  async persist(request: NotifyRequest): Promise<number[]> {
    const saved: number[] = [];
    const sentAt = new Date();

    for (const userId of [...new Set(request.userIds)]) {
      const dedupeKey = `${request.type}:room:${request.roomId}:user:${userId}`;
      if (await this.notificationRepository.existsByDedupeKey(dedupeKey)) continue;

      await this.notificationRepository.save([
        Notification.of({ userId, type: request.type, payload: request.payload, dedupeKey, sentAt }),
      ]);
      saved.push(userId);
    }

    return saved;
  }
}

/**
 * 알림 발송 서비스 (S5-1) — 이벤트 구독 핸들러가 호출하는 공용 경로.
 *
 * 1) 대상 유저별 Notification 레코드를 멱등 저장(dedupeKey=`type:room:{roomId}:user:{userId}`, 유니크). 중복 이벤트에 no-op.
 * 2) 새로 저장된 대상의 기기 토큰을 모아 PushSender로 멀티캐스트 발송.
 * 발송은 **비치명** — 실패해도(크레덴셜 없음 포함) 로깅만 하고 저장된 알림 기록은 유지한다.
 *
 * 트랜잭션 경계는 (1)의 저장에만 둔다. 외부 I/O(푸시)는 커밋 후 별도로 실행해 커넥션을 오래 잡지 않는다.
 */
@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    private readonly persister: NotificationPersister,
    private readonly deviceTokenRepository: DeviceTokenRepository,
    @Inject(PushSender) private readonly pushSender: PushSender
  ) {}

  async notify(request: NotifyRequest): Promise<void> {
    // (1) 멱등 저장 — 새로 저장된(=아직 미발송) 대상만 반환.
    const targets = await this.persister.persist(request);
    if (targets.length === 0) return; // 전부 이미 발송됨(멱등)

    // (2) 대상의 기기 토큰 수집 후 멀티캐스트(비치명).
    const deviceTokens = await this.deviceTokenRepository.findByUserIds(targets);
    if (deviceTokens.length === 0) return;

    try {
      await this.pushSender.send({
        tokens: deviceTokens.map((d) => d.token),
        title: request.title,
        body: request.body,
        data: { type: request.type, roomId: String(request.roomId) },
      });
    } catch (error) {
      this.logger.warn(`푸시 발송 실패(비치명, type=${request.type}, room=${request.roomId}): ${(error as Error).message}`);
    }
  }
}
