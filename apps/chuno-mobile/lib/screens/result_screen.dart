import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class ResultScreen extends StatelessWidget {
  final bool dnf;
  const ResultScreen({super.key, this.dnf = false});

  void _home(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: dnf ? _dnf() : _finish(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              child: Row(children: [
                Expanded(child: AppButton('다시하기', variant: dnf ? BtnVariant.outline : BtnVariant.ghost, onTap: () => _home(context))),
                const SizedBox(width: 11),
                Expanded(child: AppButton('홈으로', onTap: () => _home(context))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finish() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text('추격 종료 · 완주',
              style: TextStyle(letterSpacing: 2, color: AppColors.done, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _podium('준호', AppColors.a3, "12'40", 40, 54, '2', AppColors.panel2, AppColors.text),
              const SizedBox(width: 14),
              _podium('나', AppColors.coral, "12'02", 54, 82, '1', AppColors.coral, AppColors.onCoral, gold: true),
              const SizedBox(width: 14),
              _podium('민지', AppColors.a5, 'DNF 4.6', 40, 40, '3', AppColors.panel2, AppColors.text),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Panel(
            hud: true,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(style: TextStyle(fontSize: 13), children: [
                          TextSpan(text: '내 결과 · '),
                          TextSpan(text: '1위', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w800)),
                        ])),
                        SizedBox(height: 4),
                        Muted("완주 5.0km · 12'02", size: 11),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('820', style: numStyle(size: 30, color: AppColors.coral)),
                        const Text.rich(TextSpan(style: TextStyle(fontSize: 11, color: AppColors.muted), children: [
                          TextSpan(text: '점 · '),
                          TextSpan(text: '+82 P', style: TextStyle(color: AppColors.done, fontWeight: FontWeight.w700)),
                        ])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Row(children: [
                  _ScoreBox('등수', '300'),
                  _ScoreBox('거리', '200'),
                  _ScoreBox('완주', '220'),
                  _ScoreBox('여유', '100'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dnf() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text('추격 종료 · 미완주(DNF)',
              style: TextStyle(letterSpacing: 2, color: AppColors.alert, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(height: 8),
        const Text('🏳️', style: TextStyle(fontSize: 46)),
        const SizedBox(height: 14),
        const Text('4.1km 에서 중단', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Muted('목표 5.0km 미완주 · 4위', size: 13),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(style: TextStyle(fontSize: 13), children: [
                          TextSpan(text: '내 결과 · '),
                          TextSpan(text: 'DNF', style: TextStyle(color: AppColors.alert, fontWeight: FontWeight.w800)),
                        ])),
                        SizedBox(height: 4),
                        Muted('달린 거리 4.1km', size: 11),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('210', style: numStyle(size: 26)),
                        const Text.rich(TextSpan(style: TextStyle(fontSize: 11, color: AppColors.muted), children: [
                          TextSpan(text: '점 · '),
                          TextSpan(text: '+21 P', style: TextStyle(color: AppColors.done, fontWeight: FontWeight.w700)),
                        ])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Muted('완주 보너스 0 · 거리 164 · 등수 46\n끝까지 뛰면 완주 보너스 220점을 받았어요.', size: 11, height: 1.7),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _podium(String name, Color color, String time, double avatar, double barH, String place, Color barColor, Color placeFg, {bool gold = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(name.characters.first, color, size: avatar),
        const SizedBox(height: 7),
        Text(name, style: TextStyle(fontSize: gold ? 13 : 12, fontWeight: gold ? FontWeight.w800 : FontWeight.w500)),
        Text(time, style: numStyle(size: 11, color: gold ? AppColors.coral : AppColors.muted, w: FontWeight.w500)),
        const SizedBox(height: 7),
        Container(
          width: gold ? 62 : 58,
          height: barH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: gold
                ? LinearGradient(colors: [AppColors.coral, Color.alphaBlend(Colors.black.withValues(alpha: .45), AppColors.coral)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                : null,
            color: gold ? null : barColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: gold ? null : Border.all(color: AppColors.line),
          ),
          child: Text(place, style: TextStyle(fontSize: gold ? 26 : 20, fontWeight: FontWeight.w800, color: placeFg)),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final String value;
  const _ScoreBox(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(11)),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 3),
            Text(value, style: numStyle(size: 13)),
          ]),
        ),
      );
}
