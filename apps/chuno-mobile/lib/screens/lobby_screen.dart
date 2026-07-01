import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'countdown_screen.dart';

class LobbyScreen extends StatelessWidget {
  final Room room;
  const LobbyScreen({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final filled = Mock.lobby;
    final emptyCount = room.max - filled.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        title: Text(room.name.replaceAll('🏃 ', ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.ios_share, color: AppColors.muted, size: 18))],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              children: [
                Panel(
                  hud: true,
                  child: Column(children: [
                    Muted('목표 ${room.targetKm.toStringAsFixed(1)}km · 제한 ${room.limitMin}분', size: 11),
                    const SizedBox(height: 8),
                    Text('12:03', style: numStyle(size: 40, color: AppColors.coral)),
                    const SizedBox(height: 8),
                    const Muted('06:00 출발까지', size: 11),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 18, 4, 14),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('참가자', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    for (final p in filled) _slot(p.name + (p.host ? ' 👑' : ''), p.color, isMe: p.isMe),
                    for (var i = 0; i < emptyCount; i++) _slot('대기', AppColors.panel2, empty: true),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
            child: AppButton('▶ 데모: 카운트다운 시작', variant: BtnVariant.outline, onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => CountdownScreen(room: room)));
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
            child: Row(children: [
              Expanded(child: AppButton('나가기', variant: BtnVariant.alert, onTap: () => Navigator.of(context).pop())),
              const SizedBox(width: 11),
              Expanded(child: AppButton('방 삭제', variant: BtnVariant.ghost, onTap: () => Navigator.of(context).pop())),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _slot(String label, Color color, {bool isMe = false, bool empty = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(empty ? '+' : label.characters.first, color,
            size: 44, fg: empty ? AppColors.muted : (isMe ? AppColors.onCoral : AppColors.onCoral), dashed: empty),
        const SizedBox(height: 7),
        Text(label, style: TextStyle(fontSize: 12, color: empty ? AppColors.muted : AppColors.text)),
      ],
    );
  }
}
