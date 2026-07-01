import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  int seg = 0;

  @override
  Widget build(BuildContext context) {
    final me = Mock.ranking.firstWhere((e) => e.isMe);
    final others = (Mock.ranking.where((e) => !e.isMe).toList())..sort((a, b) => a.rank.compareTo(b.rank));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: Text('랭킹')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            children: [
              _Segment(const ['전체', '주간', '월간'], seg, (n) => setState(() => seg = n)),
              const SizedBox(height: 16),
              Panel(
                hud: true,
                child: Row(children: [
                  SizedBox(width: 30, child: Text('${me.rank}', textAlign: TextAlign.center, style: numStyle(size: 26, color: AppColors.coral))),
                  const SizedBox(width: 13),
                  Avatar('나', AppColors.coral, size: 42),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('나', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 7),
                          if (me.tier != null) Tag(me.tier!, bg: const Color(0x33AB8FCE), fg: const Color(0xFFC9B0EA)),
                        ]),
                        const SizedBox(height: 4),
                        Muted('누적 ${me.score}점 · 승률 58%', size: 11),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              for (final e in others) ...[
                Panel(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    SizedBox(width: 16, child: Text('${e.rank}', style: numStyle(size: 13, color: e.rank == 1 ? AppColors.coral : AppColors.muted))),
                    const SizedBox(width: 12),
                    Avatar(e.name.characters.first, e.color, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Row(children: [
                      Text(e.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      if (e.tier != null) ...[const SizedBox(width: 6), Tag(e.tier!, bg: const Color(0x33CBB06A), fg: const Color(0xFFE6C877))],
                    ])),
                    Text(e.score, style: numStyle(size: 13)),
                  ]),
                ),
                const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final List<String> items;
  final int active;
  final ValueChanged<int> onTap;
  const _Segment(this.items, this.active, this.onTap);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
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
        ]),
      );
}
