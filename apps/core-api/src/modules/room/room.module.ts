import { GeneralRoomService } from '@modules/room/applications/general-room.service';
import { RoomRepository } from '@modules/room/infrastructure/room.repository';
import { GeneralRoomController } from '@modules/room/presentation/general-room.controller';
import { Module } from '@nestjs/common';

@Module({
  imports: [],
  controllers: [GeneralRoomController],
  providers: [RoomRepository, GeneralRoomService],
  exports: [RoomRepository],
})
export class RoomModule {}
