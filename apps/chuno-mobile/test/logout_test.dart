// 로그아웃 플로우 검증 — AuthGate(홈) → 프로필 → 로그아웃 다이얼로그 →
// 토큰 삭제 + unauthenticated 전이 → 로그인 화면.
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
import 'package:chuno_mobile/theme/app_theme.dart';

class _FakeAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<TokenPair> login({required String provider, required String credential}) async =>
      const TokenPair(accessToken: 'a', refreshToken: 'r');

  @override
  Future<TokenPair> refresh(String refreshToken) async =>
      const TokenPair(accessToken: 'a', refreshToken: 'r');

  @override
  Future<void> logout(String refreshToken) async => logoutCalls++;
}

/// 부팅 시 온보딩 판정(getMe)이 네트워크 없이 완료되도록 하는 fake.
class _FakeUserRepository implements UserRepository {
  @override
  Future<bool> checkNickname(String nickname) async => true;
  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  }) async {}
  @override
  Future<MeModel> getMe() async => MeModel(id: 'u1', onboardedOn: DateTime(2026));
}

void main() {
  testWidgets('홈 → 프로필 로그아웃 → 토큰 삭제 + 로그인 화면', (tester) async {
    final kv = InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    });
    final repo = _FakeAuthRepository();
    final container = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(kv),
      authRepositoryProvider.overrideWithValue(repo),
      userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildAppTheme(), home: const AuthGate()),
    ));
    // 세션 복원(비동기) 완료 → 홈.
    await tester.pumpAndSettle();

    // 프로필 탭으로 이동.
    await tester.tap(find.text('프로필'));
    await tester.pumpAndSettle();

    // 로그아웃 메뉴 → 확인 다이얼로그.
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('정말 로그아웃할까요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
    await tester.pumpAndSettle();

    // 서버 무효화 호출 + 토큰 삭제.
    expect(repo.logoutCalls, 1);
    expect(await container.read(tokenStoreProvider).read(), isNull);

    // 로그인 화면 도착.
    expect(find.textContaining('카카오'), findsOneWidget);
    expect(find.text('추노'), findsOneWidget);
  });
}
