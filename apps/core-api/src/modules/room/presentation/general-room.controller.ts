import { Context, ContextKey } from '@libs/context';
import { UserGuard } from '@libs/guards';
import { GeneralRoomService } from '@modules/room/applications/general-room.service';
import { GeneralRoomQueryDto, RoomCreateDto } from '@modules/room/presentation/dto';
import { User } from '@modules/user/domain/user.entity';
import { Body, Controller, Get, Param, ParseIntPipe, Post, Query, UseGuards, Delete } from '@nestjs/common';

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
    const data = await this.generalRoomService.create({ user, ...body });

    // 4. Send response
    return { data };
  }

  @Get()
  async list(@Query() query: GeneralRoomQueryDto) {
    // 1. Destructure body, params, query
    const { statuses, minLimitMinutes, maxLimitMinutes, minTargetDistance, maxTargetDistance, ...options } = query;

    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    const data = await this.generalRoomService.list(
      { user, statuses, minLimitMinutes, maxLimitMinutes, minTargetDistance, maxTargetDistance },
      options
    );

    // 4. Send response
    return { data };
  }

  @Get(':id')
  async retrieve(@Param('id', ParseIntPipe) id: number) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    const data = await this.generalRoomService.retrieve({ user, id });

    // 4. Send response
    return { data };
  }

  @Delete(':id')
  async cancel(@Param('id', ParseIntPipe) id: number) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    await this.generalRoomService.cancel({ user, id });

    // 4. Send response
    return { data: {} };
  }

  @Post(':id/join')
  async join(@Param('id', ParseIntPipe) id: number) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    await this.generalRoomService.join({ user, id });

    // 4. Send response
    return { data: {} };
  }

  @Delete(':id/leave')
  async leave(@Param('id', ParseIntPipe) id: number) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    await this.generalRoomService.leave({ user, id });

    // 4. Send response
    return { data: {} };
  }
}
