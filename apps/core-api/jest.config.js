/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  moduleFileExtensions: ['ts', 'js', 'json'],
  testRegex: '.*\\.spec\\.ts$',
  setupFiles: ['<rootDir>/test/jest.setup.ts'],
  moduleNameMapper: {
    '^@configs$': '<rootDir>/src/configs',
    '^@libs/(.*)$': '<rootDir>/src/libs/$1',
    '^@modules/(.*)$': '<rootDir>/src/modules/$1',
    // baseUrl 스타일 절대 import(예: 'src/libs/utils')도 매핑.
    '^src/(.*)$': '<rootDir>/src/$1',
    // jose는 ESM-only 라 CJS jest에서 파싱 불가 → 목으로 대체.
    '^jose$': '<rootDir>/test/__mocks__/jose.ts',
  },
};
