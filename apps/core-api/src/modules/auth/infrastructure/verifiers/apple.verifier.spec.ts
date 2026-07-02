import { UnauthorizedException } from '@nestjs/common';
// 'jose'는 jest.config moduleNameMapper로 test/__mocks__/jose.ts에 매핑된다.
import { jwtVerify } from 'jose';
import { AppleVerifier } from './apple.verifier';
import { ConfigsService } from '@configs';

describe('AppleVerifier', () => {
  const verifier = new AppleVerifier({ apple: { clientId: 'com.chuno.app' } } as ConfigsService);

  afterEach(() => jest.clearAllMocks());

  it('idToken을 iss/aud와 함께 검증해 sub·email을 반환한다', async () => {
    (jwtVerify as jest.Mock).mockResolvedValue({ payload: { sub: 'a-sub', email: 'a@x.com' } });

    const res = await verifier.verify('id-token');

    expect(res).toEqual({ sub: 'a-sub', email: 'a@x.com' });
    expect(jwtVerify).toHaveBeenCalledWith('id-token', 'jwks', {
      issuer: 'https://appleid.apple.com',
      audience: 'com.chuno.app',
    });
  });

  it('검증 실패면 401', async () => {
    (jwtVerify as jest.Mock).mockRejectedValue(new Error('bad signature'));

    await expect(verifier.verify('bad')).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
