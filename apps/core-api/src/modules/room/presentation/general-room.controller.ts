import { Context, ContextKey } from '@libs/context';
import { UserGuard } from '@libs/guards';
import { GeneralRoomService } from '@modules/room/applications/general-room.service';
import { RoomCreateDto } from '@modules/room/presentation/dto';
import { User } from '@modules/user/domain/user.entity';
import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';

@Controller('rooms')
@UseGuards(UserGuard)
export class GeneralRoomController {
  constructor(
    private readonly generalRoomService: GeneralRoomService,
    private readonly context: Context
  ) {}

  @Post()
  async create(@Body() body: RoomCreateDto) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    await this.generalRoomService.create({ user, ...body });

    // 4. Send response
    return { data: {} };
  }

  @Get()
  async list(@Query() query: any) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    // 4. Send response
    return { data: {} };
  }

  @Get()
  async remove() {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    // 4. Send response
    return { data: {} };
  }
}
