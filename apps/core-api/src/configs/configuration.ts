import type { DataSourceOptions } from 'typeorm';

export interface GoogleConfig {
  mobile: {
    clientId: string;
  };
}

export interface AppleConfig {
  clientId: string;
}

export interface JwtConfig {
  accessSecret: string;
  accessExpiresIn: string;
  refreshExpiresInDays: number;
}

interface AppConfig {
  mysql: DataSourceOptions;
  google: GoogleConfig;
  apple: AppleConfig;
  jwt: JwtConfig;
  // dev 토큰(dev:<sub>:<email>)으로 소셜 검증을 우회하는 로컬 개발 모드.
  authDevMode: boolean;
}

export default (env: Record<string, any> = process.env): AppConfig => ({
  mysql: {
    type: 'mysql',
    port: 3306,
    host: env.MYSQL_HOST,
    username: env.MYSQL_USERNAME,
    password: env.MYSQL_PASSWORD,
    database: env.MYSQL_DATABASE,
  },
  google: {
    mobile: {
      clientId: env.GOOGLE_MOBILE_CLIENT_ID,
    },
  },
  apple: {
    clientId: env.APPLE_CLIENT_ID ?? '',
  },
  jwt: {
    accessSecret: env.JWT_ACCESS_SECRET ?? 'dev-access-secret-change-me',
    accessExpiresIn: env.JWT_ACCESS_EXPIRES_IN ?? '15m',
    refreshExpiresInDays: Number(env.JWT_REFRESH_EXPIRES_DAYS ?? 30),
  },
  authDevMode: env.AUTH_DEV_MODE === 'true',
});
