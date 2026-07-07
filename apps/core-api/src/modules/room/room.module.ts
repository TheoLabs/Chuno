import { GeneralRoomService } from '@modules/room/applications/general-room.service';
import { RoomScheduler } from '@modules/room/applications/room-scheduler.service';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { GeneralRoomController } from '@modules/room/presentation/general-room.controller';
import { LobbyGateway } from '@modules/room/presentation/lobby.gateway';
import { LobbyBroadcastHandler } from '@modules/room/presentation/lobby-broadcast.handler';
import { RoomSchedulerProcessor } from '@modules/room/presentation/room-scheduler.processor';
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { QUEUE } from '@libs/queue';

@Module({
  // room-scheduler(예약 지연잡 생산·소비) 큐 등록. domain-events 소비는 팬아웃 핸들러(LobbyBroadcastHandler)로,
  // 큐 워커 자체는 DomainEventsModule의 디스패처가 소유하므로 여기선 도메인-이벤츠 큐를 등록하지 않는다.
  imports: [BullModule.registerQueue({ name: QUEUE.ROOM_SCHEDULER })],
  controllers: [GeneralRoomController],
  providers: [
    RoomRepository,
    GeneralRoomService,
    RoomScheduler,
    LobbyGateway,
    LobbyBroadcastHandler,
    RoomSchedulerProcessor,
  ],
  exports: [RoomRepository],
})
export class RoomModule {}
