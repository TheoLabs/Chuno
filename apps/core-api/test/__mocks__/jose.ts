// jose는 ESM-only라 jest(CJS)에서 그대로 못 불러온다. 단위 테스트용 목으로 대체.
export const jwtVerify = jest.fn();
export const createRemoteJWKSet = jest.fn(() => 'jwks');
