// AuthGate 분기 검증 — 부팅 세션 복원 결과에 따라 로그인/온보딩/홈 렌더.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_gate.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/auth/auth_repository.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';
import 'package:chuno_mobile/screens/login_screen.dart';
import 'package:chuno_mobile/screens/main_shell.dart';
import 'package:chuno_mobile/screens/onboarding_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<TokenPair> login({required String provider, required String credential}) async =>
      const TokenPair(accessToken: 'a', refreshToken: 'r');
  @override
  Future<TokenPair> refresh(String refreshToken) async =>
      const TokenPair(accessToken: 'a', refreshToken: 'r');
  @override
  Future<void> logout(String refreshToken) async {}
}

/// getMe 로 온보딩 여부를 서버 권위로 판정하는 것을 대체하는 fake.
class _FakeUserRepository implements UserRepository {
  final bool onboarded;
  _FakeUserRepository({this.onboarded = false});
  @override
  Future<bool> checkNickname(String nickname) async => true;
  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  }) async {}
  @override
  Future<MeModel> getMe() async =>
      MeModel(id: 'u1', onboardedOn: onboarded ? DateTime(2026) : null);
}

Future<ProviderContainer> _pumpGate(
  WidgetTester tester, {
  Map<String, String>? seed,
  bool onboarded = false,
}) async {
  final container = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore(seed)),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    userRepositoryProvider.overrideWithValue(_FakeUserRepository(onboarded: onboarded)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: buildAppTheme(), home: const AuthGate()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('토큰 없음 → 로그인 화면', (tester) async {
    await _pumpGate(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('인증됨 + 온보딩 미완 → 온보딩 화면', (tester) async {
    await _pumpGate(tester, seed: {
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    });
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShell), findsNothing);
  });

  testWidgets('인증됨 + 서버 onboardedOn 있음 → 홈(MainShell)', (tester) async {
    await _pumpGate(
      tester,
      seed: {
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
      },
      onboarded: true,
    );
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('로그인 화면에서 시작 → 온보딩으로 전이', (tester) async {
    await _pumpGate(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.tap(find.textContaining('카카오'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('온보딩 완료 처리 → 홈으로 전이 + 재부팅 세션 유지', (tester) async {
    final container = await _pumpGate(tester, seed: {
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    });
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await container.read(authControllerProvider.notifier).completeOnboarding();
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);

    // 재부팅 시뮬레이션: 새 컨트롤러가 서버(users/me.onboardedOn)로 복원 → 홈 유지.
    final restored = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore({
        'chuno.auth.accessToken': 'a1',
        'chuno.auth.refreshToken': 'r1',
      })),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      userRepositoryProvider.overrideWithValue(_FakeUserRepository(onboarded: true)),
    ]);
    addTearDown(restored.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: restored,
      child: MaterialApp(theme: buildAppTheme(), home: const AuthGate()),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
  });
}
