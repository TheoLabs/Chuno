import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'create_room_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabHeader(
              title: Text.rich(TextSpan(children: [
                TextSpan(text: '추'),
                TextSpan(text: '노', style: TextStyle(color: AppColors.coral)),
              ])),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                children: [
                  _Filters(onTap: () => comingSoon(context, '필터는 준비 중이에요')),
                  const SizedBox(height: 14),
                  Panel(
                    color: AppColors.alertA(.10),
                    border: Border.all(color: AppColors.alertA(.30)),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                    child: Row(children: [
                      _Dot(AppColors.alert),
                      const SizedBox(width: 9),
                      const Text('LIVE', style: TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Muted('추격전 3건 진행 중', size: 12),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  for (final room in Mock.rooms) ...[
                    _RoomCard(room, onTap: () {
                      if (room.status == RoomStatus.live) {
                        comingSoon(context, '관전은 준비 중이에요');
                      } else {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => LobbyScreen(room: room)));
                      }
                    }),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 24,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
            child: Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.coralA(.42), blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 12))],
              ),
              child: const Text('＋', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700, color: AppColors.onCoral)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  final VoidCallback onTap;
  const _Filters({required this.onTap});
  @override
  Widget build(BuildContext context) {
    const labels = ['거리 ▾', '제한시간 ▾', '빈자리 ▾', '임박순'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: PillChip(labels[i], active: i == 0)),
            if (i < labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  const _RoomCard(this.room, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (tag, tagBg, tagFg) = switch (room.status) {
      RoomStatus.soon => ('곧 시작', AppColors.coralA(.18), AppColors.coral),
      RoomStatus.open => ('모집중', const Color(0xFF2B323A), const Color(0xFF9AA3AD)),
      RoomStatus.live => ('LIVE', AppColors.alertA(.15), AppColors.alert),
    };
    final isLive = room.status == RoomStatus.live;
    final action = AppButton(
      isLive ? '관전' : '참가',
      variant: room.status == RoomStatus.soon ? BtnVariant.primary : BtnVariant.ghost,
      expand: false,
      height: 36,
      fontSize: 13,
      onTap: onTap,
    );
    return Opacity(
      opacity: isLive ? 0.7 : 1,
      child: Panel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(room.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                Tag(tag, bg: tagBg, fg: tagFg),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              children: [
                TextSpan(text: '목표 ${room.targetKm.toStringAsFixed(1)}km · 제한 ${room.limitMin}분 · '),
                TextSpan(text: '${room.cur}/${room.max}명', style: const TextStyle(color: AppColors.text)),
              ],
            )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(children: [
                    Flexible(child: Muted('⏰ ${room.startInfo}', size: 12)),
                    if (room.countdown != null) ...[
                      const SizedBox(width: 8),
                      Tag(room.countdown!, bg: AppColors.coralA(.18), fg: AppColors.coral),
                    ],
                  ]),
                ),
                const SizedBox(width: 8),
                action,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
