import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { GeneralUserService } from '../applications/general-user.service';
import { Context, ContextKey } from '@libs/context';
import { User } from '../domain/user.entity';
import { GeneralUserResponseDto, GeneralUserOnboardDto, UserCheckNicknameQueryDto } from './dto';
import { UserGuard } from '@libs/guards';

@Controller('users')
@UseGuards(UserGuard)
export class GeneralUserController {
  constructor(
    private readonly generalUserService: GeneralUserService,
    private readonly context: Context
  ) {}

  @Get('me')
  getSelf() {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    // 4. Send response
    return { data: user.toInstance(GeneralUserResponseDto) };
  }

  @Put('onboard')
  async onboard(@Body() body: GeneralUserOnboardDto) {
    // 1. Destructure body, params, query
    // 2. Get context
    const user = this.context.get<User>(ContextKey.USER);

    // 3. Get result
    await this.generalUserService.onboard({ user, ...body });

    // 4. Send response
    return { data: {} };
  }

  @Get('check-nickname')
  async checkNickname(@Query() query: UserCheckNicknameQueryDto) {
    // 1. Destructure body, params, query
    // 2. Get context
    // 3. Get result
    const data = await this.generalUserService.checkAvailableNickname(query);

    // 4. Send response
    return { data };
  }
}
