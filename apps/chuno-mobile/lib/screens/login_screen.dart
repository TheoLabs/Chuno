import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_providers.dart';
import '../core/error/app_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  /// provider 별 dev 토큰. 백엔드 `AUTH_DEV_MODE=true` 에서 `dev:<sub>:<email>`
  /// 형식으로 실 소셜 키 없이 검증된다.
  static String _devToken(String provider) {
    final sub = 'dev-$provider';
    final email = 'dev+$provider@chuno.local';
    return 'dev:$sub:$email';
  }

  /// 로그인 시작. dev(디버그)에서만 실제 백엔드로 dev 토큰 로그인을 수행하고,
  /// 성공하면 AuthGate 가 authenticated 전이로 다음 화면(온보딩/홈)을 결정한다.
  ///
  /// TODO(S1-9): 릴리스에서는 실제 소셜 SDK(카카오/구글/애플)로 자격을 얻어
  /// authController.login(provider, credential=SDK토큰) 를 호출하도록 교체.
  Future<void> _start(String provider) async {
    if (_busy) return;

    // 릴리스에서는 dev 토큰을 서버로 보내지 않는다. 실 SDK 연동 전까지 안내만.
    if (kReleaseMode) {
      _snack('소셜 로그인은 준비 중입니다. (S1-9)');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            provider: provider,
            credential: _devToken(provider),
          );
      // 성공 시 AuthGate 가 화면을 교체하므로 별도 네비게이션 불필요.
    } on AppException catch (e) {
      _snack('로그인 실패: ${e.message}');
    } catch (_) {
      _snack('로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PURSUIT RUN',
                        style: TextStyle(fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w700, color: AppColors.coral)),
                    const SizedBox(height: 12),
                    const Text('추노', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 14),
                    const _Tagline(),
                    SizedBox(
                      height: 24,
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  AppButton('💬  카카오로 시작', variant: BtnVariant.custom, bg: const Color(0xFFFEE500), fg: const Color(0xFF191600), onTap: _busy ? null : () => _start('kakao')),
                  const SizedBox(height: 11),
                  AppButton('Ⓖ  구글로 시작', variant: BtnVariant.custom, bg: Colors.white, fg: const Color(0xFF1F1F1F), onTap: _busy ? null : () => _start('google')),
                  const SizedBox(height: 11),
                  AppButton(' Apple로 시작', variant: BtnVariant.custom, bg: const Color(0xFF141414), fg: Colors.white, onTap: _busy ? null : () => _start('apple')),
                  const SizedBox(height: 14),
                  const Muted('계속하면 이용약관·개인정보처리방침에 동의', size: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.7),
        children: const [
          TextSpan(text: '혼자 뛰지 마라. '),
          TextSpan(text: '쫓아라.', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          TextSpan(text: '\n어디서든 실시간으로 겨루는 추격 러닝'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
