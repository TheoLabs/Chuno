// 로그아웃 플로우 검증 — 로그아웃 → 확인 다이얼로그 → 로그인 화면.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/theme/app_theme.dart';
import 'package:chuno_mobile/screens/profile_screen.dart';

void main() {
  testWidgets('프로필 로그아웃 → 로그인 화면으로 이동', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const Scaffold(body: SafeArea(child: ProfileScreen())),
    ));

    // 로그아웃 메뉴 탭
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    // 확인 다이얼로그
    expect(find.text('정말 로그아웃할까요?'), findsOneWidget);

    // 다이얼로그의 로그아웃 버튼 탭
    await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
    await tester.pumpAndSettle();

    // 로그인 화면 도착
    expect(find.textContaining('카카오'), findsOneWidget);
    expect(find.text('추노'), findsOneWidget);
  });
}
