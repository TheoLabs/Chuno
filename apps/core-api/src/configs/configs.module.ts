import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './configuration';
import { ConfigsService } from './configs.service';

const validateConfigObject = (envConfig: Record<string, any>) => {
  if (envConfig.SWAGGER_GEN) return envConfig;

  const fullConfig = configuration(envConfig);

  const checkNodes = (obj: any, parentKey = '') => {
    Object.entries(obj).forEach(([key, value]) => {
      const currentKey = parentKey ? `${parentKey}.${key}` : key;

      if (value === undefined || Number.isNaN(value)) {
        throw new Error(`❌ .env 파일의 "${currentKey}" 설정 값이 누락되었습니다.`);
      }

      if (typeof value === 'object' && value !== null) {
        checkNodes(value, currentKey);
      }
    });
  };

  checkNodes(fullConfig);
  return envConfig;
};

@Global()
@Module({
  imports: [
    ConfigModule.forRoot({
      envFilePath: [`.env.${process.env.NODE_ENV ?? 'local'}`],
      load: [configuration],
      validate: validateConfigObject,
    }),
  ],
  providers: [ConfigsService],
  exports: [ConfigsService],
})
export class ConfigsModule {}
