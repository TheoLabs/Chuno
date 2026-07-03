import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { logger } from '@libs/logger';
import { requesterValidatorPipe } from '@libs/pipes';

(async () => {
  const app = await NestFactory.create(AppModule, { logger });
  const port = process.env.PORT ?? 3000;

  app.setGlobalPrefix('api');
  app.useGlobalPipes(requesterValidatorPipe);
  app.enableShutdownHooks();

  await app.listen(port);
})();
