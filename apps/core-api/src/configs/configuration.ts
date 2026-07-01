import type { DataSourceOptions } from 'typeorm';

export interface GoogleConfig {
  mobile: {
    clientId: string;
  };
}

export interface JwtConfig {
  accessSecret: string;
  accessExpiresIn: string;
}

interface AppConfig {
  mysql: DataSourceOptions;
  google: GoogleConfig;
  jwt: JwtConfig;
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
  jwt: {
    accessSecret: env.JWT_ACCESS_SECRET ?? 'dev-access-secret-change-me',
    accessExpiresIn: env.JWT_ACCESS_EXPIRES_IN ?? '365d',
  },
});
