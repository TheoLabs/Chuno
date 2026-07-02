import 'reflect-metadata';

// ConfigsModule의 forRoot validate가 import 시점에 실행되므로, 테스트용 더미 env를 미리 채운다.
process.env.NODE_ENV = 'test';
process.env.MYSQL_HOST ??= 'localhost';
process.env.MYSQL_USERNAME ??= 'root';
process.env.MYSQL_PASSWORD ??= '1234';
process.env.MYSQL_DATABASE ??= 'chuno_test';
process.env.GOOGLE_MOBILE_CLIENT_ID ??= 'test-google-client';
process.env.APPLE_CLIENT_ID ??= 'com.chuno.app';
process.env.AUTH_DEV_MODE ??= 'true';
