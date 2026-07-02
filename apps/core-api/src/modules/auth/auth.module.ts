import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigsService } from '@configs';
import { UserModule } from '@modules/user/user.module';
import { GoogleVerifier } from './infrastructure/verifiers/google.verifier';
import { AppleVerifier } from './infrastructure/verifiers/apple.verifier';
import { KakaoVerifier } from './infrastructure/verifiers/kakao.verifier';
import { SocialVerifierRegistry } from './infrastructure/verifiers/social-verifier.registry';
import { SocialLoginService } from './application/social-login.service';
import { AuthTokenService } from './application/auth-token.service';
import { AuthService } from './application/auth.service';
import { RefreshTokenRepository } from './infrastructure/refresh-token.repository';
import { AuthController } from './interface/auth.controller';
import { JwtAuthGuard } from './interface/jwt-auth.guard';

@Module({
  imports: [
    UserModule,
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigsService],
      useFactory: (configs: ConfigsService) => ({
        secret: configs.jwt.accessSecret,
        // expiresIn은 ms StringValue 타입을 요구하지만 설정값은 문자열('15m' 등)이라 캐스팅.
        signOptions: { expiresIn: configs.jwt.accessExpiresIn as unknown as number },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    GoogleVerifier,
    AppleVerifier,
    KakaoVerifier,
    SocialVerifierRegistry,
    SocialLoginService,
    RefreshTokenRepository,
    AuthTokenService,
    AuthService,
    JwtAuthGuard,
  ],
  // JwtAuthGuard/JwtModule은 S1-6(users/me) 등 인증 라우트에서 재사용한다.
  exports: [SocialLoginService, AuthService, AuthTokenService, JwtAuthGuard, JwtModule],
})
export class AuthModule {}
