import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

// 앱 전체 상태관리 기준 = Riverpod. 루트를 ProviderScope 로 감싼다.
void main() => runApp(const ProviderScope(child: ChunoApp()));

class ChunoApp extends StatelessWidget {
  const ChunoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '추노',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
