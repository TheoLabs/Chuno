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

export interface RedisConfig {
  host: string;
  port: number;
}

export interface FirebaseConfig {
  // 서비스계정 크레덴셜. JSON 원문 문자열 또는 JSON 파일 경로. 비어 있으면 푸시 발송기는 no-op(로깅만).
  serviceAccount: string;
}

interface AppConfig {
  mysql: DataSourceOptions;
  google: GoogleConfig;
  apple: AppleConfig;
  jwt: JwtConfig;
  redis: RedisConfig;
  firebase: FirebaseConfig;
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
  redis: {
    // 로컬은 docker redis(localhost:6379) 기본값 — env로 오버라이드.
    host: env.REDIS_HOST ?? 'localhost',
    port: Number(env.REDIS_PORT ?? 6379),
  },
  firebase: {
    // 크레덴셜 optional — 미설정(빈 문자열)이면 FirebasePushSender가 초기화 스킵 + 발송 no-op.
    serviceAccount: env.FIREBASE_SERVICE_ACCOUNT ?? '',
  },
  authDevMode: env.AUTH_DEV_MODE === 'true',
});
