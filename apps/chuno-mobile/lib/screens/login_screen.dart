import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _start(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
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
                  children: const [
                    Text('PURSUIT RUN',
                        style: TextStyle(fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.w700, color: AppColors.coral)),
                    SizedBox(height: 12),
                    Text('추노', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    SizedBox(height: 14),
                    _Tagline(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  AppButton('💬  카카오로 시작', variant: BtnVariant.custom, bg: const Color(0xFFFEE500), fg: const Color(0xFF191600), onTap: () => _start(context)),
                  const SizedBox(height: 11),
                  AppButton('Ⓖ  구글로 시작', variant: BtnVariant.custom, bg: Colors.white, fg: const Color(0xFF1F1F1F), onTap: () => _start(context)),
                  const SizedBox(height: 11),
                  AppButton(' Apple로 시작', variant: BtnVariant.custom, bg: const Color(0xFF141414), fg: Colors.white, onTap: () => _start(context)),
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
