import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/scoring/scoring_models.dart';
import '../features/scoring/scoring_providers.dart';
import '../features/users/user_models.dart';
import '../features/users/user_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// 랭킹 화면 (S4-7) — `GET /rankings?scope=` 실연동.
/// 전체/주간/월간 세그먼트, 내 순위 하이라이트 + 주변 순위.
/// 서버가 닉네임을 싣지 않으므로 타 러너는 `러너 #id`, 내 행만 닉네임/티어(users/me)로 표시.
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});
  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  int seg = 0;

  RankingScope get _scope => RankingScope.fromIndex(seg);

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(rankingProvider(_scope));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: Text('랭킹')),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
          child: _Segment(
            RankingScope.values.map((s) => s.label).toList(),
            seg,
            (n) => setState(() => seg = n),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.coral,
            backgroundColor: AppColors.panel,
            onRefresh: () async => ref.invalidate(rankingProvider(_scope)),
            child: board.when(
              data: (b) => _list(b),
              loading: () => const _RankingSkeleton(),
              error: (_, _) => _RankingError(onRetry: () => ref.invalidate(rankingProvider(_scope))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(RankingBoard b) {
    final me = b.me;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (me != null) _meCard(me) else const _NoRankCard(),
        const SizedBox(height: 14),
        if (b.items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Muted('아직 랭킹에 오른 러너가 없어요', size: 13)),
          )
        else
          for (final e in b.items) ...[
            _row(e, isMe: me != null && e.userId == me.userId),
            const SizedBox(height: 9),
          ],
      ],
    );
  }

  /// 내 순위 요약 카드 — users/me 의 닉네임/티어를 부기.
  Widget _meCard(RankingEntry me) {
    final meAsync = ref.watch(meProvider);
    final profile = meAsync.asData?.value;
    final nickname = _nicknameOf(profile);
    final tier = RunnerTier.fromWire(profile?.tier);
    return Panel(
      hud: true,
      child: Row(children: [
        SizedBox(
          width: 30,
          child: Text('${me.rank}',
              textAlign: TextAlign.center, style: numStyle(size: 26, color: AppColors.coral)),
        ),
        const SizedBox(width: 13),
        Avatar(nickname.characters.first, AppColors.coral, size: 42),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 7),
                if (tier != null) _tierTag(tier),
              ]),
              const SizedBox(height: 4),
              Muted('${_scope.label} ${_fmt(me.score)}점 · 전체 ${_fmt(me.rank)}위', size: 11),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _row(RankingEntry e, {required bool isMe}) {
    final name = isMe ? _nicknameOf(ref.watch(meProvider).asData?.value) : '러너 #${e.userId}';
    final rankColor = e.rank == 1
        ? AppColors.coral
        : (isMe ? AppColors.coral : AppColors.muted);
    return Panel(
      padding: const EdgeInsets.all(12),
      color: isMe ? AppColors.tint() : null,
      border: isMe ? Border.all(color: AppColors.coral) : null,
      child: Row(children: [
        SizedBox(width: 22, child: Text('${e.rank}', style: numStyle(size: 13, color: rankColor))),
        const SizedBox(width: 10),
        Avatar(name.characters.first, isMe ? AppColors.coral : _colorOf(e.userId), size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isMe ? AppColors.coral : AppColors.text)),
            ),
            if (e.rank == 1) ...[
              const SizedBox(width: 6),
              const Text('👑', style: TextStyle(fontSize: 13)),
            ],
          ]),
        ),
        Text('${_fmt(e.score)}점', style: numStyle(size: 13)),
      ]),
    );
  }

  static String _nicknameOf(MeModel? m) {
    final n = m?.nickname?.trim();
    return (n != null && n.isNotEmpty) ? n : '나';
  }

  static Color _colorOf(int userId) {
    const palette = [AppColors.a3, AppColors.a5, AppColors.a4, AppColors.a1, AppColors.a2];
    return palette[userId % palette.length];
  }

  static Tag _tierTag(RunnerTier tier) {
    final base = switch (tier) {
      RunnerTier.bronze => AppColors.a4,
      RunnerTier.silver => AppColors.a1,
      RunnerTier.gold => AppColors.a2,
      RunnerTier.platinum => AppColors.a3,
      RunnerTier.diamond => AppColors.a5,
    };
    return Tag(tier.label, bg: base.withValues(alpha: .2), fg: base);
  }

  /// 천 단위 구분 숫자 포맷(모노스페이스로 표시).
  static String _fmt(int n) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return '${n < 0 ? '-' : ''}$b';
  }
}

/// 참가 이력이 없어 내 순위가 없을 때의 카드.
class _NoRankCard extends StatelessWidget {
  const _NoRankCard();
  @override
  Widget build(BuildContext context) => const Panel(
        hud: true,
        child: Row(children: [
          Avatar('나', AppColors.panel2, size: 42, fg: AppColors.muted),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('아직 순위가 없어요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Muted('경주를 완주하면 랭킹에 올라요', size: 11),
              ],
            ),
          ),
        ]),
      );
}

class _RankingSkeleton extends StatelessWidget {
  const _RankingSkeleton();
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
          _bar(72),
          const SizedBox(height: 5),
          for (var i = 0; i < 5; i++) _bar(58),
        ],
      );
}

class _RankingError extends StatelessWidget {
  final VoidCallback onRetry;
  const _RankingError({required this.onRetry});
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Center(child: Muted('랭킹을 불러오지 못했어요', size: 13, color: AppColors.text)),
          const SizedBox(height: 12),
          Center(
            child: AppButton('다시 시도',
                variant: BtnVariant.outline, expand: false, height: 40, fontSize: 13, onTap: onRetry),
          ),
        ],
      );
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
