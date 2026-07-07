import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/scoring/scoring_models.dart';
import '../features/scoring/scoring_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

/// 기록 화면 (S4-8) — 누적 통계(집계) + 내 경기 기록 목록 실연동.
/// `GET /users/me/results` 한 페이지(표본)에서 통계 요약과 목록을 함께 렌더한다.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(myResultsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: Text('기록')),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.coral,
            backgroundColor: AppColors.panel,
            onRefresh: () async => ref.invalidate(myResultsProvider),
            child: page.when(
              data: (p) => _list(context, p),
              loading: () => const _HistorySkeleton(),
              error: (_, _) => _HistoryError(onRetry: () => ref.invalidate(myResultsProvider)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context, MyResultsPage p) {
    final stats = RunnerStatsSummary.fromPage(p);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(children: [
            _stat(stats.totalDistanceKm.toStringAsFixed(0), '누적 km', AppColors.coral),
            _divider(),
            _stat('${stats.raceCount}', '경기', AppColors.text),
            _divider(),
            _stat('${(stats.winRate * 100).round()}%', '승률', AppColors.done),
          ]),
        ),
        const SizedBox(height: 14),
        if (p.items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Muted('아직 경기 기록이 없어요 · 첫 추격을 시작해 보세요', size: 13)),
          )
        else
          for (final r in p.items) ...[
            _row(context, r),
            const SizedBox(height: 9),
          ],
      ],
    );
  }

  Widget _row(BuildContext context, RaceResultModel r) {
    final finished = r.finished;
    final placeColor = r.rank == 1 ? AppColors.coral : (finished ? AppColors.a4 : AppColors.muted);
    final title = finished
        ? '🏁 완주 ${r.distanceKm.toStringAsFixed(2)}km'
        : '🏳️ 미완주 ${r.distanceKm.toStringAsFixed(2)}km';
    final sub = finished
        ? '기록 ${_fmtTime(r.finishTime)} · +${r.pointsAwarded} P'
        : '달린 거리 ${r.distanceKm.toStringAsFixed(2)}km · +${r.pointsAwarded} P';
    return Panel(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(raceId: r.raceId, userId: r.userId)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Muted(sub, size: 11),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Tag('${r.rank}위', bg: placeColor.withValues(alpha: .18), fg: placeColor),
              const SizedBox(height: 4),
              Text('${r.total}점', style: numStyle(size: 11, color: AppColors.muted, w: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: numStyle(size: 22, color: color)),
          const SizedBox(height: 3),
          Muted(label, size: 11),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 34, color: AppColors.line);

  /// 초(finishTime) → m'ss. null(미완주)면 'DNF'.
  static String _fmtTime(double? sec) {
    if (sec == null) return 'DNF';
    final s = sec.round();
    final m = s ~/ 60, r = s % 60;
    return "$m'${r.toString().padLeft(2, '0')}";
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();
  Widget _bar(double h) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        height: h,
        decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(R.r)),
      );
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _bar(74),
          const SizedBox(height: 5),
          for (var i = 0; i < 4; i++) _bar(64),
        ],
      );
}

class _HistoryError extends StatelessWidget {
  final VoidCallback onRetry;
  const _HistoryError({required this.onRetry});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Center(child: Muted('기록을 불러오지 못했어요', size: 13, color: AppColors.text)),
          const SizedBox(height: 12),
          Center(
            child: AppButton('다시 시도',
                variant: BtnVariant.outline, expand: false, height: 40, fontSize: 13, onTap: onRetry),
          ),
        ],
      );
}
