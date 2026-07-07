import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/notifications/push_host.dart';

// 앱 전체 상태관리 기준 = Riverpod. 루트를 ProviderScope 로 감싼다.
void main() => runApp(const ProviderScope(child: ChunoApp()));

class ChunoApp extends StatelessWidget {
  const ChunoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 푸시 딥링크(navigator)·인앱 배너(messenger) 라우팅용 전역 키.
    final navigatorKey = GlobalKey<NavigatorState>();
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    return MaterialApp(
      title: '추노',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      home: PushHost(
        navigatorKey: navigatorKey,
        messengerKey: messengerKey,
        child: const AuthGate(),
      ),
    );
  }
}
