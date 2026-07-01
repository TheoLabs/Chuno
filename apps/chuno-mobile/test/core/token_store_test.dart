// TokenStore 저장/조회/삭제 검증 — 인메모리 KV 로 보안 저장 로직을 단위 테스트한다.
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/core/storage/token_store.dart';

void main() {
  late TokenStore store;

  setUp(() {
    store = TokenStore(InMemoryKeyValueStore());
  });

  test('처음엔 토큰이 없다', () async {
    expect(await store.read(), isNull);
    expect(await store.hasTokens(), isFalse);
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('save 후 access/refresh 를 조회한다', () async {
    await store.save(const TokenPair(accessToken: 'a1', refreshToken: 'r1'));

    expect(await store.readAccessToken(), 'a1');
    expect(await store.readRefreshToken(), 'r1');
    expect(await store.hasTokens(), isTrue);
    expect(
      await store.read(),
      const TokenPair(accessToken: 'a1', refreshToken: 'r1'),
    );
  });

  test('save 는 기존 토큰을 회전(덮어쓰기)한다', () async {
    await store.save(const TokenPair(accessToken: 'a1', refreshToken: 'r1'));
    await store.save(const TokenPair(accessToken: 'a2', refreshToken: 'r2'));

    expect(await store.readAccessToken(), 'a2');
    expect(await store.readRefreshToken(), 'r2');
  });

  test('clear 후 모두 삭제된다', () async {
    await store.save(const TokenPair(accessToken: 'a1', refreshToken: 'r1'));
    await store.clear();

    expect(await store.read(), isNull);
    expect(await store.hasTokens(), isFalse);
  });
}
