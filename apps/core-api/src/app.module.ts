import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ConfigsModule } from '@configs';
import { DatabasesModule } from './databases';
import { ContextModule } from 'src/libs/context';
import { DomainModule } from '@modules/domain.module';
import { ContextMiddleware, UUIDMiddleware } from './middlewares';
import { APP_FILTER, APP_INTERCEPTOR } from '@nestjs/core';
import { RequestLoggerInterceptor } from '@libs/interceptors';
import { ExceptionFilter } from '@libs/filters';

@Module({
  imports: [ConfigsModule, DatabasesModule, ContextModule, DomainModule],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_FILTER,
      useClass: ExceptionFilter,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: RequestLoggerInterceptor,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(ContextMiddleware, UUIDMiddleware).forRoutes('{*path}');
  }
}
