// AuthController(세션 상태) 검증 — Riverpod 컨테이너 + 오버라이드로 네트워크 없이 테스트.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/auth/auth_repository.dart';
import 'package:chuno_mobile/features/auth/auth_state.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';

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

/// 온보딩 판정을 위한 fake users API. getMe 결과/실패를 제어한다.
class _FakeUserRepository implements UserRepository {
  bool onboarded;
  bool throwOnGetMe;
  int getMeCalls = 0;
  _FakeUserRepository({this.onboarded = false, this.throwOnGetMe = false});

  @override
  Future<bool> checkNickname(String nickname) async => true;

  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  }) async =>
      onboarded = true;

  @override
  Future<MeModel> getMe() async {
    getMeCalls++;
    if (throwOnGetMe) throw const NetworkFailure();
    return MeModel(id: 'u1', onboardedOn: onboarded ? DateTime(2026) : null);
  }
}

ProviderContainer _container({
  Map<String, String>? seedTokens,
  _FakeAuthRepository? repo,
  _FakeUserRepository? users,
}) {
  return ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore(seedTokens)),
    authRepositoryProvider.overrideWithValue(repo ?? _FakeAuthRepository()),
    userRepositoryProvider.overrideWithValue(users ?? _FakeUserRepository()),
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

  test('restore: users/me.onboardedOn 있으면 onboarded=true', () async {
    final c = _container(
      seedTokens: {
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
      },
      users: _FakeUserRepository(onboarded: true),
    );
    addTearDown(c.dispose);
    await _settle(c);

    final s = c.read(authControllerProvider);
    expect(s.isAuthenticated, isTrue);
    expect(s.onboarded, isTrue);
  });

  test('restore: users/me.onboardedOn null 이면 onboarded=false(온보딩 필요)', () async {
    final c = _container(
      seedTokens: {
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
      },
      users: _FakeUserRepository(onboarded: false),
    );
    addTearDown(c.dispose);
    await _settle(c);

    expect(c.read(authControllerProvider).needsOnboarding, isTrue);
  });

  test('getMe 실패 시 세션 유지 + 캐시된 onboarded 로 폴백', () async {
    final c = _container(
      seedTokens: {
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
        'chuno.session.onboarded': 'true',
      },
      users: _FakeUserRepository(throwOnGetMe: true),
    );
    addTearDown(c.dispose);
    await _settle(c);

    final s = c.read(authControllerProvider);
    expect(s.isAuthenticated, isTrue);
    expect(s.onboarded, isTrue); // 캐시 폴백
  });

  test('completeOnboarding → onboarded=true + 캐시 갱신', () async {
    final c = _container(
      seedTokens: {
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
      },
      users: _FakeUserRepository(onboarded: false),
    );
    addTearDown(c.dispose);
    await _settle(c);
    expect(c.read(authControllerProvider).needsOnboarding, isTrue);

    await c.read(authControllerProvider.notifier).completeOnboarding();

    expect(c.read(authControllerProvider).onboarded, isTrue);
    expect(await c.read(keyValueStoreProvider).read('chuno.session.onboarded'), 'true');
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
