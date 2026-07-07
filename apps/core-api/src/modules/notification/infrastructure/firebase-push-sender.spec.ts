import { FirebasePushSender } from './firebase-push-sender';

/**
 * S5-1 — 크레덴셜 없으면 초기화 스킵 + send no-op(부팅/테스트 안전). 실제 FCM 발송은 검증 범위 밖.
 */
describe('FirebasePushSender (S5-1, 크레덴셜 없음)', () => {
  const makeSender = (serviceAccount: string) =>
    new FirebasePushSender({ firebase: { serviceAccount } } as never);

  it('serviceAccount 빈 값 → onModuleInit no-op(예외 없음)', () => {
    const sender = makeSender('');
    expect(() => sender.onModuleInit()).not.toThrow();
  });

  it('크레덴셜 없으면 send는 no-op으로 resolve(발송 안 함, 예외 없음)', async () => {
    const sender = makeSender('');
    sender.onModuleInit();
    await expect(sender.send({ tokens: ['tok-a'], title: 't', body: 'b' })).resolves.toBeUndefined();
  });

  it('잘못된 크레덴셜(파싱 실패)도 초기화 스킵(부팅 안전)', () => {
    const sender = makeSender('not-a-json-and-not-a-file');
    expect(() => sender.onModuleInit()).not.toThrow();
  });
});
