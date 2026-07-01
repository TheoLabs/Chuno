import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'main_shell.dart';

class _Step {
  final String icon;
  final String title;
  final Widget desc;
  final Widget? field;
  final String cta;
  const _Step(this.icon, this.title, this.desc, this.field, this.cta);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int i = 0;
  int _level = 1;
  final _nick = TextEditingController(text: '러너_추노');

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  List<_Step> get steps => [
        _Step('🏷️', '닉네임을 정해주세요', const Muted('경주와 랭킹에서 보여질 이름이에요.', size: 14, height: 1.6),
            AppTextField(controller: _nick, hint: '닉네임 (2~12자)', maxLength: 12), '다음'),
        _Step('🎽', '러닝 레벨은?', const Muted('방 추천에 참고돼요.', size: 14, height: 1.6),
            _seg(['입문', '중급', '고급'], _level, (n) => setState(() => _level = n)), '다음'),
        _Step('📍', '위치 권한이 필요해요',
            const Text.rich(
              TextSpan(style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.7), children: [
                TextSpan(text: 'GPS로 '),
                TextSpan(text: '뛴 거리만', style: TextStyle(color: AppColors.text)),
                TextSpan(text: ' 측정해 실시간 순위를 공유합니다.\n'),
                TextSpan(text: '좌표는 서버에 전송하지 않아요.', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
              ]),
              textAlign: TextAlign.center,
            ),
            const Panel(child: Muted('🔒 화면을 꺼도 측정하려면\n"항상 허용(백그라운드)"이 필요합니다.', size: 12, height: 1.8)),
            '위치 권한 허용'),
        _Step('🎯', '준비 완료!', const Muted('이제 추격전에 뛰어들 시간이에요.', size: 14, height: 1.6), null, '시작하기'),
      ];

  static Widget _seg(List<String> items, int active, ValueChanged<int> onTap) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(R.sm),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var n = 0; n < items.length; n++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(n),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: n == active ? AppColors.coral : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(items[n],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: n == active ? FontWeight.w700 : FontWeight.w500,
                          color: n == active ? AppColors.onCoral : AppColors.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (i < steps.length - 1) {
      setState(() => i++);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (r) => false,
      );
    }
  }

  void _prev() {
    FocusScope.of(context).unfocus();
    if (i > 0) {
      setState(() => i--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = steps[i];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _prev,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(padding: EdgeInsets.all(4), child: Text('←', style: TextStyle(fontSize: 20, color: AppColors.muted))),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var n = 0; n < steps.length; n++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: n == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: n == i ? AppColors.coral : AppColors.panel2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: SingleChildScrollView(
                  key: ValueKey(i),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.icon, style: const TextStyle(fontSize: 58)),
                      const SizedBox(height: 18),
                      Text(s.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      s.desc,
                      if (s.field != null) ...[const SizedBox(height: 20), s.field!],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: AppButton(s.cta, onTap: _next),
            ),
          ],
        ),
      ),
    );
  }
}
