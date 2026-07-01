import { Global, Module } from '@nestjs/common';
import { TypeOrmModule } from './typeorm';

@Global()
@Module({
  imports: [TypeOrmModule],
  exports: [TypeOrmModule],
})
export class DatabasesModule {}
