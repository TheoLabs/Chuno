import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigsModule } from '@configs';
import { DatabasesModule } from './databases';
import { ContextModule } from 'src/libs/context';

@Module({
  imports: [ConfigsModule, DatabasesModule, ContextModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
