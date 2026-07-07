import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_providers.dart';
import '../features/scoring/scoring_models.dart';
import '../features/scoring/scoring_providers.dart';
import '../features/users/user_models.dart';
import '../features/users/user_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'store_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    // 전체 랭킹 내 순위(있으면 신원 라인에 부기). 실패/미참가면 순위 표기 생략.
    final myRank = ref.watch(rankingProvider(RankingScope.all)).asData?.value.me?.rank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabHeader(
          title: const Text('프로필'),
          trailing: [
            GestureDetector(
              onTap: () => comingSoon(context, '프로필 수정은 준비 중이에요'),
              behavior: HitTestBehavior.opaque,
              child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.edit_outlined, size: 20, color: AppColors.muted)),
            ),
            const SizedBox(width: 2),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            children: [
              me.when(
                data: (m) => _identity(m, myRank),
                loading: () => const _IdentitySkeleton(),
                error: (_, _) => _IdentityError(onRetry: () => ref.invalidate(meProvider)),
              ),
              const SizedBox(height: 18),
              Panel(
                hud: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Muted('보유 포인트', size: 11),
                        Text('1,240 P', style: numStyle(size: 26, color: AppColors.coral)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreScreen())),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [BoxShadow(color: AppColors.coralA(.42), blurRadius: 18, spreadRadius: -8, offset: const Offset(0, 6))],
                        ),
                        child: const Icon(Icons.storefront_rounded, color: AppColors.onCoral, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _menu('🛡️ 광고 제거 (한 달권)', trailing: '500 P →', onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StoreScreen()));
              }),
              _menu('🔔 알림 설정', trailing: '→', onTap: () => comingSoon(context, '알림 설정은 준비 중이에요')),
              _menu('📍 위치 권한', trailing: '허용됨 →', onTap: () => comingSoon(context, '시스템 설정으로 이동 (준비 중)')),
              _menu('로그아웃', color: AppColors.alert, onTap: () => _logout(context, ref)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    // async gap 전에 확보 — 다이얼로그 이후 ref/context가 defunct여도 안전.
    final auth = ref.read(authControllerProvider.notifier);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('로그아웃', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text('정말 로그아웃할까요?', style: TextStyle(fontSize: 14, color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('로그아웃', style: TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    // 토큰 삭제 + 세션 무효화. 상태가 unauthenticated 로 바뀌면 AuthGate 가
    // 로그인 화면을 렌더한다.
    await auth.logout();
    // AuthGate 위에 쌓인 라우트가 있으면 정리해 로그인 화면이 드러나게 한다.
    navigator.popUntil((r) => r.isFirst);
  }

  /// users/me 실데이터로 상단 신원(아바타·닉네임·티어·레벨) 표시.
  /// 전체 랭킹 내 순위([myRank], 랭킹 실연동)를 레벨 라벨에 부기한다(없으면 생략).
  Widget _identity(MeModel m, int? myRank) {
    final nickname = (m.nickname != null && m.nickname!.trim().isNotEmpty) ? m.nickname!.trim() : '러너';
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1) : '나';
    final level = RunnerLevel.fromWire(m.level);
    final tier = RunnerTier.fromWire(m.tier);
    final rankLabel = myRank != null ? '전체 $myRank위' : null;
    final levelLabel = level != null ? '${level.label} 러너' : null;
    final levelLine = [levelLabel, rankLabel].whereType<String>().join(' · ');
    return Column(children: [
      Avatar(initial, AppColors.coral, size: 82),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text(
            nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (tier != null) ...[
          const SizedBox(width: 8),
          _tierTag(tier),
        ],
      ]),
      if (levelLine.isNotEmpty) ...[
        const SizedBox(height: 4),
        Muted(levelLine, size: 11),
      ],
    ]);
  }

  /// 티어별 태그 색(참가자 팔레트 재사용).
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

  Widget _menu(String label, {String? trailing, Color? color, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.all(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: color ?? AppColors.text)),
              if (trailing != null) Text(trailing, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      );
}

/// 프로필 로딩 중 스켈레톤 — 실제 신원 블록과 같은 높이감(오버플로우 방지).
class _IdentitySkeleton extends StatelessWidget {
  const _IdentitySkeleton();

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(R.sm),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 82, height: 82, decoration: const BoxDecoration(color: AppColors.panel2, shape: BoxShape.circle)),
      const SizedBox(height: 12),
      _bar(120, 18),
      const SizedBox(height: 8),
      _bar(90, 11),
    ]);
  }
}

/// 프로필 조회 실패 — 크래시 없이 폴백 아바타 + 재시도.
class _IdentityError extends StatelessWidget {
  final VoidCallback onRetry;
  const _IdentityError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Avatar('나', AppColors.panel2, size: 82, fg: AppColors.muted),
      const SizedBox(height: 12),
      const Muted('프로필을 불러오지 못했어요', size: 13, color: AppColors.text),
      const SizedBox(height: 10),
      AppButton('다시 시도', variant: BtnVariant.outline, expand: false, height: 40, fontSize: 13, onTap: onRetry),
    ]);
  }
}
