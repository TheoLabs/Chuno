import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/login_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/onboarding_screen.dart';
import '../../theme/app_theme.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

/// 앱 진입점. 부팅 시 세션(토큰) 복원 결과에 따라 화면을 분기한다.
///
/// - unknown/로딩 → 스플래시
/// - unauthenticated → 로그인
/// - authenticated + 온보딩 미완 → 온보딩
/// - authenticated + 온보딩 완료 → 홈(MainShell)
///
/// 세션 복원은 [AuthController.build] → restore() 에서 자동 트리거되므로
/// 여기서는 상태를 구독해 렌더만 분기한다. 상태 전이(로그인/로그아웃)에 따라
/// 최하단 라우트가 교체되며 스택이 초기화된다.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    switch (auth.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return auth.onboarded ? const MainShell() : const OnboardingScreen();
    }
  }
}

/// 세션 확인 중 표시하는 다크+코랄 스플래시.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('추노',
                style: TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 1)),
            SizedBox(height: 22),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
