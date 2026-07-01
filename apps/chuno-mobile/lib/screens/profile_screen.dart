import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'store_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              Column(children: [
                Avatar('나', AppColors.coral, size: 82),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('러너_추노', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Tag('💎 다이아', bg: const Color(0x33AB8FCE), fg: const Color(0xFFC9B0EA)),
                ]),
                const SizedBox(height: 4),
                const Muted('중급 러너 · 전체 7위', size: 11),
              ]),
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
              _menu('로그아웃', color: AppColors.alert, onTap: () => _logout(context)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout(BuildContext context) async {
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
    if (ok != true || !context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
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
