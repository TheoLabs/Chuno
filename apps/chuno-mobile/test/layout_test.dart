// 레이아웃 오버플로우 회귀 테스트 — 작은 화면(390x700)에서 각 화면이
// RenderFlex overflow 없이 렌더링되는지 확인.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/data/mock.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/legal/legal_models.dart';
import 'package:chuno_mobile/features/legal/legal_providers.dart';
import 'package:chuno_mobile/features/legal/legal_repository.dart';
import 'package:chuno_mobile/features/rooms/room_models.dart';
import 'package:chuno_mobile/features/rooms/room_providers.dart';
import 'package:chuno_mobile/features/rooms/room_repository.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';
import 'package:chuno_mobile/theme/app_theme.dart';
import 'package:chuno_mobile/screens/login_screen.dart';
import 'package:chuno_mobile/screens/onboarding_screen.dart';
import 'package:chuno_mobile/screens/main_shell.dart';
import 'package:chuno_mobile/screens/create_room_screen.dart';
import 'package:chuno_mobile/screens/lobby_screen.dart';
import 'package:chuno_mobile/screens/race_screen.dart';
import 'package:chuno_mobile/screens/result_screen.dart';
import 'package:chuno_mobile/screens/ranking_screen.dart';
import 'package:chuno_mobile/screens/history_screen.dart';
import 'package:chuno_mobile/screens/profile_screen.dart';
import 'package:chuno_mobile/screens/store_screen.dart';
import 'package:chuno_mobile/screens/terms_doc_screen.dart';

/// 온보딩 닉네임 확인이 네트워크 없이 통과하도록 하는 fake.
class _FakeUserRepository implements UserRepository {
  @override
  Future<bool> checkNickname(String nickname) async => true;
  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<int> legalDocumentIds,
  }) async {}
  @override
  Future<MeModel> getMe() async => const MeModel(id: 'u1');
}

/// 활성 문서 list/retrieve 를 네트워크 없이 제공하는 fake.
class _FakeLegalRepository implements LegalDocumentRepository {
  @override
  Future<List<LegalDocument>> list({required List<String> types}) async => const [
        LegalDocument(id: 1, type: 'terms-of-service', version: 'v1.0', title: '이용약관', isRequired: true, status: 'ACTIVE'),
        LegalDocument(id: 2, type: 'privacy-policy', version: 'v1.0', title: '개인정보', isRequired: true, status: 'ACTIVE'),
        LegalDocument(id: 3, type: 'location-service', version: 'v1.0', title: '위치기반', isRequired: true, status: 'ACTIVE'),
        LegalDocument(id: 4, type: 'marketing', version: 'v1.0', title: '마케팅', isRequired: false, status: 'ACTIVE'),
      ];
  @override
  Future<LegalDocument> retrieve(int id) async => LegalDocument(
        id: id, type: 'terms-of-service', version: 'v1.0', title: '이용약관', isRequired: true,
        status: 'ACTIVE', content: '제1조 (목적) 본 약관은 ... (전문)', expectedActivateOn: '2026-01-01',
      );
}

/// 방목록/생성을 네트워크 없이 제공하는 fake.
class _FakeRoomRepository implements RoomRepository {
  @override
  Future<List<RoomModel>> list({
    List<RoomStatus>? statuses,
    int? minLimitMinutes,
    int? maxLimitMinutes,
    int? minTargetDistance,
    int? maxTargetDistance,
    int? page,
    int? limit,
    String? sort,
    String? order,
  }) async =>
      const [
        RoomModel(
          id: 1, hostUserId: 'h1', name: '5km 새벽 추격', targetDistance: 5, limitMinutes: 40,
          maxParticipants: 6, scheduledStartOn: '2030-01-01 06:00:00', status: RoomStatus.starting,
          currentParticipantsCount: 3, isHost: false,
        ),
        RoomModel(
          id: 2, hostUserId: 'h2', name: '10km 챌린지', targetDistance: 10, limitMinutes: 70,
          maxParticipants: 8, scheduledStartOn: '2030-01-01 07:30:00', status: RoomStatus.recruiting,
          currentParticipantsCount: 2, isHost: false,
        ),
      ];
  @override
  Future<int> create({
    required String name,
    required int targetDistance,
    required int limitMinutes,
    required int maxParticipants,
    required String scheduledStartOn,
  }) async =>
      99;
  @override
  Future<void> join(int id) async {}
  @override
  Future<RoomModel> retrieve(int id) async => const RoomModel(
        id: 1, hostUserId: 'h1', name: '5km 새벽 추격', targetDistance: 5, limitMinutes: 40,
        maxParticipants: 6, scheduledStartOn: '2030-01-01 06:00:00', status: RoomStatus.starting,
        currentParticipantsCount: 3, isHost: true,
      );
  @override
  Future<void> delete(int id) async {}
}

const _sampleDoc = LegalDocument(
  id: 1, type: 'terms-of-service', version: 'v1.0', title: '이용약관', isRequired: true, status: 'ACTIVE',
);

void main() {
  // 탭 바디(Scaffold 없음)는 Scaffold로 감싼다.
  Widget wrapTab(Widget child) => Scaffold(body: SafeArea(child: child));

  // Consumer 화면(로그인/온보딩/프로필)을 위해 ProviderScope 로 감싼다.
  // 보안 저장소는 인메모리로, users API 는 fake 로 override 해 네트워크/플러그인 의존을 제거한다.
  Widget app(Widget home) => ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          legalDocumentRepositoryProvider.overrideWithValue(_FakeLegalRepository()),
          roomRepositoryProvider.overrideWithValue(_FakeRoomRepository()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      );

  final cases = <String, Widget>{
    'login': const LoginScreen(),
    'onboarding': const OnboardingScreen(),
    'mainShell(home)': const MainShell(),
    'createRoom': const CreateRoomScreen(),
    'lobby': LobbyScreen(room: Mock.rooms[0]),
    'lobby(detail)': LobbyScreen(room: Mock.rooms[0], roomId: 1),
    'result(완주)': const ResultScreen(),
    'result(dnf)': const ResultScreen(dnf: true),
    'ranking': wrapTab(const RankingScreen()),
    'history': wrapTab(const HistoryScreen()),
    'profile': wrapTab(const ProfileScreen()),
    'store': const StoreScreen(),
    'termsDoc(로딩)': const TermsDocScreen(document: _sampleDoc),
  };

  cases.forEach((name, screen) {
    testWidgets('$name 오버플로우 없이 렌더된다', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(screen));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$name 렌더 예외');
    });
  });

  testWidgets('race(라이브) 오버플로우 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(RaceScreen(room: Mock.rooms[0])));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'race 렌더 예외');
    // 타이머 정리를 위해 위젯 폐기
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('onboarding(약관 동의 단계) 오버플로우 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const OnboardingScreen()));
    await tester.pump();
    // 닉네임 → 러닝레벨 → 약관 동의 (2번 다음)
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(find.text('전체 동의 (선택 포함)'), findsOneWidget);
    expect(find.text('동의하고 계속'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '약관 동의 단계 렌더 예외');
  });

  testWidgets('termsDoc(전문 로드) 오버플로우 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const TermsDocScreen(document: _sampleDoc)));
    await tester.pumpAndSettle(); // retrieve 완료 → 전문 렌더
    expect(find.text('제1조 (목적) 본 약관은 ... (전문)'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'termsDoc 전문 렌더 예외');
  });

  testWidgets('약관 동의: 필수 미충족 시 다음 단계로 진행되지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const OnboardingScreen()));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    // 아무 것도 체크하지 않고 CTA 탭 → 위치 권한 단계로 넘어가지 않아야 함
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 허용'), findsNothing);
    expect(find.text('동의하고 계속'), findsOneWidget);

    // 전체 동의 체크 후에는 진행 가능
    await tester.tap(find.text('전체 동의 (선택 포함)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    expect(find.text('위치 권한 허용'), findsOneWidget);
  });
}
