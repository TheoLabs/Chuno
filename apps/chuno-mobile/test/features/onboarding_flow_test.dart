// 온보딩 저장(S1-10) 연동 검증 — 닉네임 확인 → 레벨 → 약관 → onboard 저장 → 홈 전이.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_gate.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/auth/auth_repository.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';
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

class _FakeUserRepository implements UserRepository {
  bool available;
  bool failOnboard;
  bool onboarded = false;
  int onboardCalls = 0;
  String? lastNickname;
  String? lastLevel;
  List<Consent>? lastConsents;
  _FakeUserRepository({this.available = true, this.failOnboard = false});

  @override
  Future<bool> checkNickname(String nickname) async => available;

  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  }) async {
    onboardCalls++;
    if (failOnboard) {
      throw const RequestFailure(message: '이미 사용 중인 닉네임입니다.', statusCode: 400);
    }
    lastNickname = nickname;
    lastLevel = level;
    lastConsents = consents;
    onboarded = true;
  }

  @override
  Future<MeModel> getMe() async =>
      MeModel(id: 'u1', onboardedOn: onboarded ? DateTime(2026) : null);
}

Future<void> _pump(WidgetTester tester, _FakeUserRepository users) async {
  final container = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    })),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    userRepositoryProvider.overrideWithValue(users),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: buildAppTheme(), home: const AuthGate()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('닉네임 중복 → 오류 표시 + 다음 단계로 진행하지 않음', (tester) async {
    final users = _FakeUserRepository(available: false);
    await _pump(tester, users);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
    expect(find.text('러닝 레벨은?'), findsNothing); // 다음 단계로 안 넘어감
  });

  testWidgets('전체 플로우: 확인 → 저장 → 홈(MainShell) 전이 + consents 전달', (tester) async {
    final users = _FakeUserRepository(available: true);
    await _pump(tester, users);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // 닉네임 → 레벨
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('러닝 레벨은?'), findsOneWidget);

    // 레벨(기본 중급=intermediate) → 약관
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 필수 3종 포함 전체 동의 → 위치
    await tester.tap(find.text('전체 동의 (선택 포함)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 허용'), findsOneWidget);

    // 위치 → 준비 완료
    await tester.tap(find.text('위치 권한 허용'));
    await tester.pumpAndSettle();

    // 시작하기 → onboard 저장 → 홈
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(users.onboardCalls, 1);
    expect(users.lastNickname, '러너_추노');
    expect(users.lastLevel, 'intermediate');
    // 필수 3종 포함(marketing 도 전체동의로 포함되어 4개).
    final types = users.lastConsents!.map((c) => c.type).toSet();
    expect(types.containsAll({'terms', 'privacy', 'location'}), isTrue);
    for (final c in users.lastConsents!) {
      expect(c.documentVersion, '1.0');
    }
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('onboard 실패(400) → 스낵바 + 홈 전이 없음(크래시 금지)', (tester) async {
    final users = _FakeUserRepository(available: true, failOnboard: true);
    await _pump(tester, users);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 동의 (선택 포함)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('위치 권한 허용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pump(); // 스낵바 프레임

    expect(users.onboardCalls, 1);
    expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
