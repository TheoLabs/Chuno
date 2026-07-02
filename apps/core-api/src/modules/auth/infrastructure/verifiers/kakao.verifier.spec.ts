import { UnauthorizedException } from '@nestjs/common';
import { KakaoVerifier } from './kakao.verifier';

describe('KakaoVerifier', () => {
  const verifier = new KakaoVerifier();

  afterEach(() => jest.restoreAllMocks());

  it('사용자 API의 id를 sub로, email을 반환한다', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ id: 12345, kakao_account: { email: 'k@x.com' } }),
    } as unknown as Response);

    const res = await verifier.verify('kakao-token');

    expect(res).toEqual({ sub: '12345', email: 'k@x.com' });
  });

  it('실패 응답이면 401', async () => {
    jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: false,
      json: async () => ({}),
    } as unknown as Response);

    await expect(verifier.verify('bad')).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
