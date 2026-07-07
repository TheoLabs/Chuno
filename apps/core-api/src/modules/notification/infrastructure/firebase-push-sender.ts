import { existsSync, readFileSync } from 'node:fs';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { App, ServiceAccount, cert, getApps, getApp, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { ConfigsService } from '@configs';
import { PushMessage, PushSender } from '@modules/notification/applications/push-sender';

/**
 * FCM/APNs 발송기 (S5-1) — `firebase-admin` 멀티캐스트 구현.
 *
 * 크레덴셜 처리(부팅/테스트 안전): `FIREBASE_SERVICE_ACCOUNT`(JSON 원문 또는 파일 경로)가
 * - **비었거나 파싱/초기화에 실패하면** → 초기화 스킵 + `send`는 warn 로깅 no-op(예외 던지지 않음).
 * - 유효하면 → Firebase 앱을 1회 초기화하고 `sendEachForMulticast`로 실제 발송.
 *
 * 발송 실패(부분 실패 포함)는 상위(NotificationService)에서 비치명 처리하므로 여기서는 로깅만 한다.
 */
@Injectable()
export class FirebasePushSender extends PushSender implements OnModuleInit {
  private readonly logger = new Logger(FirebasePushSender.name);
  private app: App | null = null;

  constructor(private readonly configs: ConfigsService) {
    super();
  }

  onModuleInit(): void {
    const raw = this.configs.firebase.serviceAccount?.trim();
    if (!raw) {
      this.logger.warn('FIREBASE_SERVICE_ACCOUNT 미설정 — 푸시 발송기 비활성화(발송 no-op).');
      return;
    }

    try {
      const credential = this.loadCredential(raw);
      // HMR/재부팅 시 중복 초기화 방지 — 기존 앱 재사용.
      this.app = getApps().length ? getApp() : initializeApp({ credential: cert(credential) });
      this.logger.log('Firebase 푸시 발송기 초기화 완료.');
    } catch (error) {
      this.app = null;
      this.logger.warn(`Firebase 초기화 실패 — 푸시 발송기 비활성화(발송 no-op): ${(error as Error).message}`);
    }
  }

  async send(message: PushMessage): Promise<void> {
    if (!this.app) {
      this.logger.warn(`푸시 발송기 비활성 — no-op(대상 ${message.tokens.length}건, "${message.title}").`);
      return;
    }
    if (message.tokens.length === 0) return;

    const response = await getMessaging(this.app).sendEachForMulticast({
      tokens: message.tokens,
      notification: { title: message.title, body: message.body },
      data: message.data,
    });

    if (response.failureCount > 0) {
      this.logger.warn(`푸시 부분 실패 — 성공 ${response.successCount} / 실패 ${response.failureCount}.`);
    }
  }

  /** 크레덴셜 로드 — JSON 원문(`{`로 시작) 또는 파일 경로. */
  private loadCredential(raw: string): ServiceAccount {
    const json = raw.startsWith('{') ? raw : this.readFileOrThrow(raw);
    return JSON.parse(json) as ServiceAccount;
  }

  private readFileOrThrow(path: string): string {
    if (!existsSync(path)) {
      throw new Error(`서비스계정 파일을 찾을 수 없습니다: ${path}`);
    }
    return readFileSync(path, 'utf-8');
  }
}
