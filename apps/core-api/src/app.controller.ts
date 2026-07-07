import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get('health')
  health(): Promise<{ status: string; redis: 'ok' | 'down' }> {
    return this.appService.health();
  }
}
