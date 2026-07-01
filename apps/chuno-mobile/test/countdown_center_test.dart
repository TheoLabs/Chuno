import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chuno_mobile/theme/app_theme.dart';
import 'package:chuno_mobile/data/mock.dart';
import 'package:chuno_mobile/screens/countdown_screen.dart';

void main() {
  testWidgets('카운트다운 숫자가 화면 가로 중앙에 있다', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: CountdownScreen(room: Mock.rooms[0])));
    await tester.pump();

    final c = tester.getCenter(find.text('3'));
    // ignore: avoid_print
    print('>>> number center dx = ${c.dx} (screen width 390, 중앙=195)');
    await tester.pumpWidget(const SizedBox()); // 타이머 정리
    expect(c.dx, closeTo(195, 1.5));
  });
}
