// AuthController(세션 상태) 검증 — Riverpod 컨테이너 + 오버라이드로 네트워크 없이 테스트.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/auth/auth_repository.dart';
import 'package:chuno_mobile/features/auth/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<TokenPair> login({required String provider, required String credential}) async =>
      const TokenPair(accessToken: 'login-access', refreshToken: 'login-refresh');

  @override
  Future<TokenPair> refresh(String refreshToken) async =>
      const TokenPair(accessToken: 'refreshed-access', refreshToken: 'refreshed-refresh');

  @override
  Future<void> logout(String refreshToken) async => logoutCalls++;
}

ProviderContainer _container({
  Map<String, String>? seedTokens,
  _FakeAuthRepository? repo,
}) {
  return ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore(seedTokens)),
    authRepositoryProvider.overrideWithValue(repo ?? _FakeAuthRepository()),
  ]);
}

/// 컨트롤러 build() 를 트리거하고 내부 비동기 _restore() 가 끝날 때까지 대기.
Future<void> _settle(ProviderContainer c) async {
  c.read(authControllerProvider); // build() 실행 → _restore 시작
  for (var i = 0; i < 50; i++) {
    if (c.read(authControllerProvider).isResolved) return;
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('토큰이 없으면 unauthenticated 로 확정된다', () async {
    final c = _container();
    addTearDown(c.dispose);

    expect(c.read(authControllerProvider).status, AuthStatus.unknown);
    await _settle(c);
    expect(c.read(authControllerProvider), const AuthState.unauthenticated());
  });

  test('저장된 토큰이 있으면 authenticated 로 확정된다', () async {
    final c = _container(seedTokens: {
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    });
    addTearDown(c.dispose);

    await _settle(c);
    expect(c.read(authControllerProvider).isAuthenticated, isTrue);
  });

  test('login → 토큰 저장 + authenticated', () async {
    final c = _container();
    addTearDown(c.dispose);
    await _settle(c);

    await c.read(authControllerProvider.notifier).login(
          provider: 'kakao',
          credential: 'code',
        );

    expect(c.read(authControllerProvider).isAuthenticated, isTrue);
    expect(
      await c.read(tokenStoreProvider).read(),
      const TokenPair(accessToken: 'login-access', refreshToken: 'login-refresh'),
    );
  });

  test('logout → 서버 무효화 호출 + 토큰 삭제 + unauthenticated', () async {
    final repo = _FakeAuthRepository();
    final c = _container(
      seedTokens: {
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
      },
      repo: repo,
    );
    addTearDown(c.dispose);
    await _settle(c);

    await c.read(authControllerProvider.notifier).logout();

    expect(repo.logoutCalls, 1);
    expect(await c.read(tokenStoreProvider).read(), isNull);
    expect(c.read(authControllerProvider), const AuthState.unauthenticated());
  });

  test('onSessionExpired → unauthenticated', () async {
    final c = _container(seedTokens: {
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    });
    addTearDown(c.dispose);
    await _settle(c);

    c.read(authControllerProvider.notifier).onSessionExpired();
    expect(c.read(authControllerProvider), const AuthState.unauthenticated());
  });
}
