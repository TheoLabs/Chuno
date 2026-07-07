import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type DataSourceOptions } from 'typeorm';
import { AppleConfig, FirebaseConfig, GoogleConfig, JwtConfig, RedisConfig } from './configuration';

@Injectable()
export class ConfigsService {
  constructor(private readonly configService: ConfigService) {}

  isLocal() {
    return process.env.NODE_ENV === 'local';
  }

  isProduction() {
    return process.env.NODE_ENV === 'production';
  }

  get mysql() {
    return this.configService.get<DataSourceOptions>('mysql')!;
  }

  get google() {
    return this.configService.get<GoogleConfig>('google')!;
  }

  get apple() {
    return this.configService.get<AppleConfig>('apple')!;
  }

  get jwt() {
    return this.configService.get<JwtConfig>('jwt')!;
  }

  get redis() {
    return this.configService.get<RedisConfig>('redis')!;
  }

  get firebase() {
    return this.configService.get<FirebaseConfig>('firebase')!;
  }

  get authDevMode() {
    return this.configService.get<boolean>('authDevMode')!;
  }
}
