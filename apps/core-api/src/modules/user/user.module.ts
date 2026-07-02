import { Module } from '@nestjs/common';
import { UserRepository } from './infrastructure/user.repository';
import { GeneralUserController } from './presentation/general-user.controller';
import { GeneralUserService } from './applications/general-user.service';

@Module({
  imports: [],
  controllers: [GeneralUserController],
  providers: [UserRepository, GeneralUserService],
  exports: [UserRepository],
})
export class UserModule {}
