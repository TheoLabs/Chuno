import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { QUEUE } from '@libs/queue';
import { RoomModule } from '@modules/room/room.module';
import { RaceRepository } from '@modules/race/infrastructure/race.repository';
import { RaceService } from '@modules/race/applications/race.service';
import { RaceScheduler } from '@modules/race/applications/race-scheduler.service';
import { RaceGateway } from '@modules/race/presentation/race.gateway';
import { RaceBroadcaster } from '@modules/race/presentation/race-broadcaster';
import { RaceCreationHandler } from '@modules/race/presentation/race-creation.handler';
import { RaceBroadcastHandler } from '@modules/race/presentation/race-broadcast.handler';
import { RaceSchedulerProcessor } from '@modules/race/presentation/race-scheduler.processor';

/**
 * Race 모듈 (S3-3~S3-6).
 *
 * - `race-scheduler` 큐 등록(제한시간 finalize 지연잡 생산·소비).
 * - RoomModule import → RoomRepository로 방 참가자 로드(Race 생성).
 * - 도메인 이벤트 소비는 팬아웃 핸들러(RaceCreationHandler·RaceBroadcastHandler)로 — domain-events 큐 워커는
 *   DomainEventsModule의 디스패처가 소유하므로 여기서 도메인-이벤츠 큐를 등록하지 않는다(경쟁 소비 방지).
 */
@Module({
  imports: [BullModule.registerQueue({ name: QUEUE.RACE_SCHEDULER }), RoomModule],
  providers: [
    RaceRepository,
    RaceService,
    RaceScheduler,
    RaceGateway,
    RaceBroadcaster,
    RaceCreationHandler,
    RaceBroadcastHandler,
    RaceSchedulerProcessor,
  ],
  exports: [RaceRepository, RaceService],
})
export class RaceModule {}
