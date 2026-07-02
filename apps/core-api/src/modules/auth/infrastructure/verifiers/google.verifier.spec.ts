import { UnauthorizedException } from '@nestjs/common';

jest.mock('google-auth-library');
import { OAuth2Client } from 'google-auth-library';
import { GoogleVerifier } from './google.verifier';
import { ConfigsService } from '@configs';

describe('GoogleVerifier', () => {
  const verifyIdToken = jest.fn();
  let verifier: GoogleVerifier;

  beforeEach(() => {
    (OAuth2Client as unknown as jest.Mock).mockImplementation(() => ({ verifyIdToken }));
    verifier = new GoogleVerifier({ google: { mobile: { clientId: 'client-id' } } } as ConfigsService);
  });

  afterEach(() => jest.clearAllMocks());

  it('idToken을 clientId audience로 검증해 sub·email을 반환한다', async () => {
    verifyIdToken.mockResolvedValue({ getPayload: () => ({ sub: 'g-sub', email: 'g@x.com' }) });

    const res = await verifier.verify('id-token');

    expect(verifyIdToken).toHaveBeenCalledWith({ idToken: 'id-token', audience: 'client-id' });
    expect(res).toEqual({ sub: 'g-sub', email: 'g@x.com' });
  });

  it('payload에 sub가 없으면 401', async () => {
    verifyIdToken.mockResolvedValue({ getPayload: () => ({}) });

    await expect(verifier.verify('bad')).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
