/** 푸시 발송 메시지 — 여러 기기 토큰에 동일 알림을 멀티캐스트. */
export interface PushMessage {
  tokens: string[];
  title: string;
  body: string;
  /** FCM data 페이로드(문자열 값만 허용). 라우팅용 roomId 등. */
  data?: Record<string, string>;
}

/**
 * 푸시 발송 포트 (S5-1) — FCM/APNs 등 구현체를 추상화. `Notification` 컨텍스트가 이 포트에만 의존한다.
 *
 * 구현체는 크레덴셜이 없으면 초기화를 스킵하고 `send`를 no-op(로깅)으로 처리해 부팅/테스트를 안전하게 유지한다.
 * 추상 클래스 = DI 주입 토큰 겸 인터페이스.
 */
export abstract class PushSender {
  abstract send(message: PushMessage): Promise<void>;
}
