import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

const double _rowH = 70;
const double _target = 5.0;

class RaceScreen extends StatefulWidget {
  final Room room;
  const RaceScreen({super.key, required this.room});
  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  late List<RaceRunner> runners;
  int remain = 18 * 60 + 42;
  bool discon = false;
  Timer? _t;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    runners = Mock.raceRunners();
    _recomputeRanks();
    _t = Timer.periodic(const Duration(milliseconds: 850), (_) {
      setState(() {
        for (final r in runners) {
          if (r.km < _target) {
            r.km = min(_target, r.km + r.base * (0.55 + _rng.nextDouble() * 0.9));
          }
        }
        remain = max(0, remain - 3);
        _recomputeRanks();
      });
    });
  }

  void _recomputeRanks() {
    final sorted = [...runners]..sort((a, b) => b.km.compareTo(a.km));
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].rank = i;
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _clock() {
    final m = remain ~/ 60, s = remain % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  RaceRunner get _me => runners.firstWhere((r) => r.isMe);

  @override
  Widget build(BuildContext context) {
    final sorted = [...runners]..sort((a, b) => b.km.compareTo(a.km));
    final me = _me;
    final target = me.rank == 0 ? null : sorted[me.rank - 1];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // mission bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.alert, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('추격 중 · 5.0km', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.coral)),
                      ]),
                      Text(_clock(), style: numStyle(size: 19, color: AppColors.alert, w: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Muted('남은 시간 · 실시간 순위', size: 11),
                ],
              ),
            ),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: AppColors.coralA(.3)),
            if (discon)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.tint(),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: AppColors.coralA(.35)),
                ),
                child: const Muted('⚠️ 연결 끊김 — 내 거리는 로컬 GPS로 계속 측정 중, 상대 순위 동기화 대기…',
                    size: 11, color: AppColors.coral),
              ),
            // leaderboard
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final r in runners) _row(r, r == target),
                  ],
                ),
              ),
            ),
            // lock strip
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.tint(),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: AppColors.coralA(.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Muted('타겟까지 ', size: 12),
                    Text(
                      target == null ? '선두 유지' : '+${(target.km - me.km).toStringAsFixed(2)}km',
                      style: numStyle(size: 13, color: target == null ? AppColors.coral : AppColors.alert),
                    ),
                  ]),
                  Row(children: [
                    const Muted('내 페이스 ', size: 12),
                    Text("5'30\"", style: numStyle(size: 13, color: AppColors.coral)),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(children: [
                Expanded(child: AppButton('연결끊김 시뮬', variant: BtnVariant.ghost, height: 42, fontSize: 12, onTap: () => setState(() => discon = !discon))),
                const SizedBox(width: 9),
                Expanded(child: AppButton('완주 → 결과', variant: BtnVariant.outline, height: 42, fontSize: 12, onTap: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResultScreen()));
                })),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: AppButton('그만두기 (DNF)', variant: BtnVariant.alert, onTap: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResultScreen(dnf: true)));
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(RaceRunner r, bool isTarget) {
    final done = r.km >= _target;
    Color border = AppColors.line;
    Color barColor = const Color(0xFFAEB4BC);
    List<BoxShadow>? shadow;
    Color? bg;
    if (r.isMe) {
      border = AppColors.coral;
      bg = AppColors.tint();
      barColor = AppColors.coral;
      shadow = [BoxShadow(color: AppColors.coralA(.32), blurRadius: 28, spreadRadius: -14, offset: const Offset(0, 10))];
    } else if (isTarget) {
      border = AppColors.alert;
      barColor = AppColors.alert;
    }
    if (done) barColor = AppColors.done;

    final gap = done
        ? null
        : (r.rank == 0 ? '선두' : 'Δ ${(([...runners]..sort((a, b) => b.km.compareTo(a.km)))[r.rank - 1].km - r.km).toStringAsFixed(2)}km');

    return AnimatedPositioned(
      key: ValueKey(r.id),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      top: r.rank * _rowH,
      left: 0,
      right: 0,
      height: _rowH - 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: bg ?? AppColors.panel,
          borderRadius: BorderRadius.circular(R.r),
          border: Border.all(color: border),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            SizedBox(width: 18, child: Text('${r.rank + 1}', textAlign: TextAlign.center, style: numStyle(size: 14, color: r.isMe ? AppColors.coral : AppColors.muted))),
            const SizedBox(width: 11),
            Avatar(r.name.characters.first, r.color, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    if (r.isMe) ...[
                      const SizedBox(width: 7),
                      const Text('나', style: TextStyle(fontSize: 11, color: AppColors.coral, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: const Color(0xFF0D1016), border: Border.all(color: const Color(0xFF20242B))),
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 700),
                        alignment: Alignment.centerLeft,
                        widthFactor: (r.km / _target).clamp(0, 1).toDouble(),
                        child: Container(decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${r.km.toStringAsFixed(2)}km', style: numStyle(size: 14, w: FontWeight.w800)),
                const SizedBox(height: 2),
                done
                    ? const Text('🏁 완주', style: TextStyle(fontSize: 11, color: AppColors.done))
                    : Text(gap!, style: TextStyle(fontSize: 11, color: r.rank == 0 ? AppColors.coral : AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
