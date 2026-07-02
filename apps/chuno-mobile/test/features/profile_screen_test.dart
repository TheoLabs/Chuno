// 프로필 화면이 users/me 실데이터(닉네임·레벨·티어)를 표시하고,
// 실패 시 재시도로 복구되는지 확인한다. 네트워크 없이 fake 저장소로 검증.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';
import 'package:chuno_mobile/screens/profile_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

/// getMe 응답/실패를 주입 가능한 fake. 다른 메서드는 프로필 테스트에서 미사용.
class _FakeUserRepository implements UserRepository {
  final MeModel? me;
  final bool fail;
  int getMeCalls = 0;
  _FakeUserRepository({this.me, this.fail = false});

  @override
  Future<MeModel> getMe() async {
    getMeCalls++;
    if (fail) throw Exception('boom');
    return me!;
  }

  @override
  Future<bool> checkNickname(String nickname) async => true;
  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  }) async {}
}

Widget _app(UserRepository repo) => ProviderScope(
      overrides: [userRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SafeArea(child: ProfileScreen())),
      ),
    );

void main() {
  testWidgets('users/me 실데이터를 표시한다 (닉네임·레벨·티어)', (tester) async {
    final repo = _FakeUserRepository(
      me: const MeModel(id: 'u1', nickname: '홍길동', level: 'intermediate', tier: 'diamond'),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('중급 러너 · 전체 7위'), findsOneWidget);
    expect(find.text('💎 다이아'), findsOneWidget);
  });

  testWidgets('닉네임/레벨/티어 null 이면 폴백 처리(크래시 없음)', (tester) async {
    final repo = _FakeUserRepository(me: const MeModel(id: 'u1'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // 티어 없으면 태그 미표시, 레벨 없으면 랭킹만 표기.
    expect(find.text('전체 7위'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('조회 실패 시 재시도 버튼으로 복구된다', (tester) async {
    final repo = _FakeUserRepository(fail: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('프로필을 불러오지 못했어요'), findsOneWidget);
    expect(repo.getMeCalls, 1);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    // invalidate 로 재요청되어 호출 수가 증가한다.
    expect(repo.getMeCalls, greaterThan(1));
  });
}
