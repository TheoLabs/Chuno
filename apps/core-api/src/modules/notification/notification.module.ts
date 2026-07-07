import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { QUEUE } from '@libs/queue';
import { RoomModule } from '@modules/room/room.module';
import { RaceModule } from '@modules/race/race.module';
import { DeviceTokenRepository } from '@modules/notification/infrastructure/device-token.repository';
import { NotificationRepository } from '@modules/notification/infrastructure/notification.repository';
import { FirebasePushSender } from '@modules/notification/infrastructure/firebase-push-sender';
import { PushSender } from '@modules/notification/applications/push-sender';
import { DeviceTokenService } from '@modules/notification/applications/device-token.service';
import { NotificationService, NotificationPersister } from '@modules/notification/applications/notification.service';
import { RaceNotificationService } from '@modules/notification/applications/race-notification.service';
import { NotificationScheduler } from '@modules/notification/applications/notification-scheduler.service';
import { DeviceTokenController } from '@modules/notification/presentation/device-token.controller';
import { ParticipantJoinedHandler } from '@modules/notification/presentation/participant-joined.handler';
import { RaceStartingHandler } from '@modules/notification/presentation/race-starting.handler';
import { RaceFinishedHandler } from '@modules/notification/presentation/race-finished.handler';
import { NotificationSchedulerProcessor } from '@modules/notification/presentation/notification-scheduler.processor';

/**
 * Notification 모듈 (S5-1) — 푸시 발송(FCM/APNs) + 기기 토큰 + 이벤트 구독 알림.
 *
 * - `notification-scheduler` 큐 등록(출발 리마인더 지연잡 생산·소비).
 * - RoomModule·RaceModule import → 이벤트 payload(roomId)로 방 참가자·러너를 로드해 대상 산출.
 * - 도메인 이벤트 소비는 팬아웃 핸들러(ParticipantJoined·RoomStarting·RaceFinished)로 — domain-events 큐 워커는
 *   DomainEventsModule 디스패처가 소유하므로 여기서 등록하지 않는다(핸들러 프로바이더 등록만으로 확장).
 * - PushSender 포트 = FirebasePushSender(크레덴셜 없으면 no-op) 바인딩.
 */
@Module({
  imports: [BullModule.registerQueue({ name: QUEUE.NOTIFICATION_SCHEDULER }), RoomModule, RaceModule],
  controllers: [DeviceTokenController],
  providers: [
    DeviceTokenRepository,
    NotificationRepository,
    { provide: PushSender, useClass: FirebasePushSender },
    DeviceTokenService,
    NotificationPersister,
    NotificationService,
    RaceNotificationService,
    NotificationScheduler,
    ParticipantJoinedHandler,
    RaceStartingHandler,
    RaceFinishedHandler,
    NotificationSchedulerProcessor,
  ],
})
export class NotificationModule {}
