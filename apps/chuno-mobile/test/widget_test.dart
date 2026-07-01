// 기본 스모크 테스트 — 앱이 로그인 화면으로 부팅되는지 확인.
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/main.dart';

void main() {
  testWidgets('앱이 로그인 화면으로 부팅된다', (WidgetTester tester) async {
    await tester.pumpWidget(const ChunoApp());
    expect(find.text('추노'), findsOneWidget);
    expect(find.textContaining('카카오'), findsOneWidget);
  });
}
