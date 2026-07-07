import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/scoring/scoring_models.dart';
import '../features/scoring/scoring_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// 경주 결과 화면 (S4-6).
///
/// - [userId] 가 있으면 실연동: 라이브 종료 직후엔 raceId 미확보 → 내 최신 기록을 폴백 폴링,
///   [raceId] 도 있으면(기록 상세 진입) 그 경주 결과를 바로 조회한다. `GET /races/:id/result`.
/// - 둘 다 없으면(데모/카운트다운 목업) 기존 정적 화면을 렌더한다. [dnf] 는 초기 표시 힌트.
class ResultScreen extends StatelessWidget {
  final int? raceId;
  final int? userId;
  final bool dnf;
  const ResultScreen({super.key, this.raceId, this.userId, this.dnf = false});

  bool get _real => userId != null;

  void _home(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _real
                  ? _RealResultBody(args: (raceId: raceId, userId: userId!), dnfHint: dnf)
                  : SingleChildScrollView(child: dnf ? _demoDnf() : _demoFinish()),
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

  // ── 데모(정적) 화면 — roomId/userId 미지정(카운트다운 목업) 진입용 ──────────────
  Widget _demoFinish() {
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
              _podiumCol('준호', AppColors.a3, "12'40", 40, 54, '2', AppColors.panel2, AppColors.text),
              const SizedBox(width: 14),
              _podiumCol('나', AppColors.coral, "12'02", 54, 82, '1', AppColors.coral, AppColors.onCoral, gold: true),
              const SizedBox(width: 14),
              _podiumCol('민지', AppColors.a5, 'DNF 4.6', 40, 40, '3', AppColors.panel2, AppColors.text),
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

  Widget _demoDnf() {
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
}

// ══════════════════════════════════════════════════════════════════════
// 실연동 결과 (S4-6)
// ══════════════════════════════════════════════════════════════════════

class _RealResultBody extends ConsumerWidget {
  final RaceResultArgs args;
  final bool dnfHint;
  const _RealResultBody({required this.args, required this.dnfHint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(raceResultViewProvider(args));
    return view.when(
      data: (v) => SingleChildScrollView(child: _content(v)),
      loading: () => _loading(),
      error: (_, _) => _error(context, ref),
    );
  }

  Widget _loading() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 2.4),
            ),
            const SizedBox(height: 18),
            Muted(dnfHint ? '추격 종료 · 결과 집계 중…' : '완주! 결과 집계 중…', size: 13),
          ],
        ),
      );

  Widget _error(BuildContext context, WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏁', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 14),
              const Muted('결과를 아직 불러오지 못했어요', size: 14, color: AppColors.text),
              const SizedBox(height: 6),
              const Muted('집계에 잠시 시간이 걸릴 수 있어요.', size: 12),
              const SizedBox(height: 16),
              AppButton('다시 시도',
                  variant: BtnVariant.outline,
                  expand: false,
                  height: 42,
                  fontSize: 13,
                  onTap: () => ref.invalidate(raceResultViewProvider(args))),
            ],
          ),
        ),
      );

  Widget _content(RaceResultView v) {
    final mine = v.mine;
    final finished = mine.finished;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            finished ? '추격 종료 · 완주' : '추격 종료 · 미완주(DNF)',
            style: TextStyle(
                letterSpacing: 2,
                color: finished ? AppColors.done : AppColors.alert,
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
        _podium(v),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _breakdown(mine),
        ),
      ],
    );
  }

  Widget _podium(RaceResultView v) {
    final top = v.set.podium;
    RaceResultModel? at(int rank) {
      for (final r in top) {
        if (r.rank == rank) return r;
      }
      return null;
    }

    final cols = <Widget>[];
    void addCol(RaceResultModel? r, double avatar, double barH, {bool gold = false}) {
      if (r == null) return;
      final isMe = r.userId == v.mine.userId;
      final name = isMe ? '나' : '러너 #${r.userId}';
      final color = gold || isMe ? AppColors.coral : _colorOf(r.userId);
      final sub = r.finished ? _fmtTime(r.finishTime) : 'DNF ${r.distanceKm.toStringAsFixed(1)}';
      cols.add(_podiumCol(
        name,
        color,
        sub,
        avatar,
        barH,
        '${r.rank}',
        gold ? AppColors.coral : AppColors.panel2,
        gold ? AppColors.onCoral : AppColors.text,
        gold: gold,
      ));
    }

    // 2위(좌) · 1위(중앙, gold) · 3위(우) 순 — 없으면 그 자리는 비운다.
    addCol(at(2), 40, 54);
    if (cols.isNotEmpty) cols.add(const SizedBox(width: 14));
    addCol(at(1), 54, 82, gold: true);
    final rank3 = at(3);
    if (rank3 != null) cols.add(const SizedBox(width: 14));
    addCol(rank3, 40, 40);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: cols,
      ),
    );
  }

  Widget _breakdown(RaceResultModel m) {
    final finished = m.finished;
    final resultLabel = finished ? '${m.rank}위' : 'DNF';
    final sub = finished
        ? '완주 ${m.distanceKm.toStringAsFixed(2)}km · ${_fmtTime(m.finishTime)}'
        : '달린 거리 ${m.distanceKm.toStringAsFixed(2)}km';
    return Panel(
      hud: finished,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(style: const TextStyle(fontSize: 13), children: [
                      const TextSpan(text: '내 결과 · '),
                      TextSpan(
                        text: resultLabel,
                        style: TextStyle(
                            color: finished ? AppColors.coral : AppColors.alert,
                            fontWeight: FontWeight.w800),
                      ),
                    ])),
                    const SizedBox(height: 4),
                    Muted(sub, size: 11),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${m.total}', style: numStyle(size: 30, color: finished ? AppColors.coral : AppColors.text)),
                  Text.rich(TextSpan(style: const TextStyle(fontSize: 11, color: AppColors.muted), children: [
                    const TextSpan(text: '점 · '),
                    TextSpan(
                        text: '+${m.pointsAwarded} P',
                        style: const TextStyle(color: AppColors.done, fontWeight: FontWeight.w700)),
                  ])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            _ScoreBox('등수', '${m.rankScore}'),
            _ScoreBox('거리', '${m.distanceScore}'),
            _ScoreBox('완주', '${m.finishBonus}'),
            _ScoreBox('여유', '${m.marginScore}'),
          ]),
        ],
      ),
    );
  }

  static Color _colorOf(int userId) {
    const palette = [AppColors.a3, AppColors.a5, AppColors.a4, AppColors.a1, AppColors.a2];
    return palette[userId % palette.length];
  }

  /// 초(finishTime) → m'ss. null(미완주)면 'DNF'.
  static String _fmtTime(double? sec) {
    if (sec == null) return 'DNF';
    final s = sec.round();
    final m = s ~/ 60, r = s % 60;
    return "$m'${r.toString().padLeft(2, '0')}";
  }
}

/// 시상대 1열(공용) — 데모/실연동 모두 사용.
Widget _podiumCol(String name, Color color, String time, double avatar, double barH, String place, Color barColor, Color placeFg, {bool gold = false}) {
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
