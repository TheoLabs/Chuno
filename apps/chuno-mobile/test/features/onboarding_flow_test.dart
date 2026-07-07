// 온보딩 저장(S1-10) + 활성 문서 API 연동(S1-17) 검증
// — 진입 시 legal-documents list fetch → 닉네임 확인 → 레벨 → 약관(동의한 문서 id)
//   → onboard(legalDocumentIds) → 홈 전이. 문서 fetch 실패 처리 포함.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_gate.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/auth/auth_repository.dart';
import 'package:chuno_mobile/features/legal/legal_models.dart';
import 'package:chuno_mobile/features/legal/legal_providers.dart';
import 'package:chuno_mobile/features/legal/legal_repository.dart';
import 'package:chuno_mobile/features/race/geo.dart';
import 'package:chuno_mobile/features/race/location_service.dart';
import 'package:chuno_mobile/features/race/race_providers.dart';
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
  List<int>? lastLegalDocumentIds;
  _FakeUserRepository({this.available = true, this.failOnboard = false});

  @override
  Future<bool> checkNickname(String nickname) async => available;

  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<int> legalDocumentIds,
  }) async {
    onboardCalls++;
    if (failOnboard) {
      throw const RequestFailure(message: '이미 사용 중인 닉네임입니다.', statusCode: 400);
    }
    lastNickname = nickname;
    lastLevel = level;
    lastLegalDocumentIds = legalDocumentIds;
    onboarded = true;
  }

  @override
  Future<MeModel> getMe() async =>
      MeModel(id: 'u1', onboardedOn: onboarded ? DateTime(2026) : null);
}

class _FakeLegalRepository implements LegalDocumentRepository {
  bool failList;
  int listCalls = 0;
  _FakeLegalRepository({this.failList = false});

  static const _docs = [
    LegalDocument(id: 1, type: 'terms-of-service', version: 'v1.0', title: '이용약관', isRequired: true, status: 'ACTIVE'),
    LegalDocument(id: 2, type: 'privacy-policy', version: 'v1.0', title: '개인정보', isRequired: true, status: 'ACTIVE'),
    LegalDocument(id: 3, type: 'location-service', version: 'v1.0', title: '위치기반', isRequired: true, status: 'ACTIVE'),
    LegalDocument(id: 4, type: 'marketing', version: 'v1.0', title: '마케팅', isRequired: false, status: 'ACTIVE'),
  ];

  @override
  Future<List<LegalDocument>> list({required List<String> types}) async {
    listCalls++;
    if (failList) throw const NetworkFailure();
    return _docs;
  }

  @override
  Future<LegalDocument> retrieve(int id) async => LegalDocument(
        id: id, type: 't', version: 'v1.0', title: '문서', isRequired: true,
        status: 'ACTIVE', content: '전문 내용', expectedActivateOn: '2026-01-01',
      );
}

/// 위치 권한 단계가 플러그인 없이 통과하도록 하는 fake(항상 허용).
class _FakeLocationService implements LocationService {
  @override
  Future<LocationAuth> currentAuth() async => LocationAuth.always;
  @override
  Future<LocationAuth> ensureAlwaysPermission() async => LocationAuth.always;
  @override
  Future<bool> openSettings() async => true;
  @override
  Stream<GeoSample> positions() => const Stream.empty();
}

Future<void> _pump(
  WidgetTester tester,
  _FakeUserRepository users, {
  _FakeLegalRepository? legal,
}) async {
  final container = ProviderContainer(overrides: [
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'a1',
      'chuno.auth.refreshToken': 'r1',
    })),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    userRepositoryProvider.overrideWithValue(users),
    legalDocumentRepositoryProvider.overrideWithValue(legal ?? _FakeLegalRepository()),
    locationServiceProvider.overrideWithValue(_FakeLocationService()),
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

  testWidgets('전체 플로우: list fetch → 저장 → 홈 전이 + legalDocumentIds 전달', (tester) async {
    final users = _FakeUserRepository(available: true);
    final legal = _FakeLegalRepository();
    await _pump(tester, users, legal: legal);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(legal.listCalls, 1); // 진입 시 1회 왕복

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
    // 전체동의 → 필수3 + marketing 의 id 전송(1,2,3,4).
    expect(users.lastLegalDocumentIds, [1, 2, 3, 4]);
    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('필수만 동의(marketing 제외) → legalDocumentIds 에 4 미포함', (tester) async {
    final users = _FakeUserRepository(available: true);
    await _pump(tester, users);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 필수 3종만 개별 체크(marketing 미체크)
    await tester.tap(find.text('이용약관 동의'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개인정보 수집·이용 동의'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('위치기반서비스 이용동의'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('위치 권한 허용'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(users.lastLegalDocumentIds, [1, 2, 3]); // marketing(4) 제외
  });

  testWidgets('문서 fetch 실패 → 에러 UI + 진행 차단, 재시도로 회복', (tester) async {
    final users = _FakeUserRepository(available: true);
    final legal = _FakeLegalRepository(failList: true);
    await _pump(tester, users, legal: legal);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 에러 메시지 + 다시 시도 버튼, 동의 항목 미노출
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('전체 동의 (선택 포함)'), findsNothing);

    // 필수 미충족 → CTA 눌러도 다음 단계로 못 감
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 허용'), findsNothing);

    // 재시도 → 성공 시 동의 항목 렌더
    legal.failList = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('전체 동의 (선택 포함)'), findsOneWidget);
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
