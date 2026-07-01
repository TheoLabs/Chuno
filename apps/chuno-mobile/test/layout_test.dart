// 레이아웃 오버플로우 회귀 테스트 — 작은 화면(390x700)에서 각 화면이
// RenderFlex overflow 없이 렌더링되는지 확인.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/data/mock.dart';
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

void main() {
  // 탭 바디(Scaffold 없음)는 Scaffold로 감싼다.
  Widget wrapTab(Widget child) => Scaffold(body: SafeArea(child: child));

  final cases = <String, Widget>{
    'login': const LoginScreen(),
    'onboarding': const OnboardingScreen(),
    'mainShell(home)': const MainShell(),
    'createRoom': const CreateRoomScreen(),
    'lobby': LobbyScreen(room: Mock.rooms[0]),
    'result(완주)': const ResultScreen(),
    'result(dnf)': const ResultScreen(dnf: true),
    'ranking': wrapTab(const RankingScreen()),
    'history': wrapTab(const HistoryScreen()),
    'profile': wrapTab(const ProfileScreen()),
    'store': const StoreScreen(),
  };

  cases.forEach((name, screen) {
    testWidgets('$name 오버플로우 없이 렌더된다', (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$name 렌더 예외');
    });
  });

  testWidgets('race(라이브) 오버플로우 없이 렌더된다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: RaceScreen(room: Mock.rooms[0])));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'race 렌더 예외');
    // 타이머 정리를 위해 위젯 폐기
    await tester.pumpWidget(const SizedBox());
  });
}
