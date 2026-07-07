import { GeneralRoomService } from '@modules/room/applications/general-room.service';
import { RoomScheduler } from '@modules/room/applications/room-scheduler.service';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { GeneralRoomController } from '@modules/room/presentation/general-room.controller';
import { LobbyGateway } from '@modules/room/presentation/lobby.gateway';
import { LobbyBroadcastProcessor } from '@modules/room/presentation/lobby-broadcast.processor';
import { RoomSchedulerProcessor } from '@modules/room/presentation/room-scheduler.processor';
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { QUEUE } from '@libs/queue';

@Module({
  // domain-events(브로드캐스트 소비) + room-scheduler(예약 지연잡 생산·소비) 큐 등록.
  imports: [
    BullModule.registerQueue({ name: QUEUE.DOMAIN_EVENTS }, { name: QUEUE.ROOM_SCHEDULER }),
  ],
  controllers: [GeneralRoomController],
  providers: [
    RoomRepository,
    GeneralRoomService,
    RoomScheduler,
    LobbyGateway,
    LobbyBroadcastProcessor,
    RoomSchedulerProcessor,
  ],
  exports: [RoomRepository],
})
export class RoomModule {}
