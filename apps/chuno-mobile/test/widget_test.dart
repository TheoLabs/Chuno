// 기본 스모크 테스트 — 앱이 (토큰 없을 때) 로그인 화면으로 부팅되는지 확인.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/main.dart';

void main() {
  testWidgets('앱이 로그인 화면으로 부팅된다', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
      child: const ChunoApp(),
    ));
    // 부팅 시 세션 복원(unknown → unauthenticated) 완료 대기.
    await tester.pumpAndSettle();

    expect(find.text('추노'), findsOneWidget);
    expect(find.textContaining('카카오'), findsOneWidget);
  });
}
