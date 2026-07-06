import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/rooms/room_models.dart' hide RoomStatus;
import '../features/rooms/room_providers.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'countdown_screen.dart';

class LobbyScreen extends ConsumerWidget {
  /// 표시용 폴백(생성/목록에서 넘겨받은 값). [roomId] 가 있으면 상세 조회가 우선한다.
  final Room room;

  /// 서버 방 id. 있으면 `GET /rooms/:id` 상세를 로드해 렌더한다.
  final int? roomId;
  const LobbyScreen({super.key, required this.room, this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = roomId;
    // roomId 없으면(목록 미연동 경로) 폴백 목업으로 즉시 렌더.
    if (id == null) {
      return _Scaffold(view: _LobbyView.fromMock(room), room: room);
    }
    final detail = ref.watch(roomDetailProvider(id));
    return detail.when(
      data: (r) => _Scaffold(view: _LobbyView.fromModel(r), room: room),
      loading: () => _Scaffold(view: _LobbyView.fromMock(room), room: room, loading: true),
      error: (_, _) => _Scaffold(
        view: _LobbyView.fromMock(room),
        room: room,
        onRetry: () => ref.invalidate(roomDetailProvider(id)),
      ),
    );
  }
}

/// 로비 표시용 뷰모델 — 상세(RoomModel) 또는 폴백(mock Room)에서 생성.
class _LobbyView {
  final String name;
  final String metaLabel; // "목표 5km · 제한 40분"
  final String startBig; // 대형 시각 표기(HH:mm) 또는 '—'
  final String startCaption; // "출발 예정" / "12분 후"
  final int cur;
  final int max;
  final bool isHost;

  const _LobbyView({
    required this.name,
    required this.metaLabel,
    required this.startBig,
    required this.startCaption,
    required this.cur,
    required this.max,
    required this.isHost,
  });

  factory _LobbyView.fromModel(RoomModel r) {
    final at = r.startAt;
    String p(int n) => n.toString().padLeft(2, '0');
    return _LobbyView(
      name: r.name,
      metaLabel: '목표 ${r.targetDistance}km · 제한 ${r.limitMinutes}분',
      startBig: at == null ? '—' : '${p(at.hour)}:${p(at.minute)}',
      startCaption: r.countdownLabel ?? '출발 예정',
      cur: r.currentParticipantsCount,
      max: r.maxParticipants,
      isHost: r.isHost,
    );
  }

  factory _LobbyView.fromMock(Room r) {
    return _LobbyView(
      name: r.name.replaceAll('🏃 ', ''),
      metaLabel: '목표 ${r.targetKm.toStringAsFixed(1)}km · 제한 ${r.limitMin}분',
      startBig: r.startInfo.split(' ').first,
      startCaption: r.countdown ?? '출발 예정',
      cur: r.cur,
      max: r.max,
      isHost: r.status != RoomStatus.live,
    );
  }
}

class _Scaffold extends StatelessWidget {
  final _LobbyView view;
  final Room room; // 카운트다운 데모 진입용(기존 목업 플로우 유지)
  final bool loading;
  final VoidCallback? onRetry;
  const _Scaffold({required this.view, required this.room, this.loading = false, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final emptyCount = (view.max - view.cur).clamp(0, view.max);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        title: Text(view.name.replaceAll('🏃 ', ''), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
                if (onRetry != null) ...[
                  Panel(
                    color: AppColors.alertA(.10),
                    border: Border.all(color: AppColors.alertA(.30)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      const Expanded(child: Muted('방 정보를 불러오지 못했어요', size: 12, color: AppColors.text)),
                      AppButton('다시 시도', variant: BtnVariant.outline, expand: false, height: 32, fontSize: 12, onTap: onRetry),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                Panel(
                  hud: true,
                  child: Column(children: [
                    Muted(view.metaLabel, size: 11),
                    const SizedBox(height: 8),
                    if (loading)
                      const SizedBox(
                        height: 40,
                        width: 40,
                        child: Center(child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 2.4)),
                      )
                    else
                      Text(view.startBig, style: numStyle(size: 40, color: AppColors.coral)),
                    const SizedBox(height: 8),
                    Muted(loading ? '불러오는 중…' : view.startCaption, size: 11),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 14),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('참가자', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Muted('${view.cur}/${view.max}명', size: 12),
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
                    for (var i = 0; i < view.cur; i++)
                      _slot(_slotLabel(i), _slotColor(i)),
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

  // 상세 응답엔 참가자 명단이 없어 라벨은 표시용(방장=나 강조).
  String _slotLabel(int i) => i == 0 && view.isHost ? '나 👑' : '러너';
  Color _slotColor(int i) {
    const palette = [AppColors.a3, AppColors.a5, AppColors.a4, AppColors.a1, AppColors.a2];
    if (i == 0 && view.isHost) return AppColors.coral;
    return palette[i % palette.length];
  }

  Widget _slot(String label, Color color, {bool empty = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(empty ? '+' : label.characters.first, color,
            size: 44, fg: empty ? AppColors.muted : AppColors.onCoral, dashed: empty),
        const SizedBox(height: 7),
        Text(label, style: TextStyle(fontSize: 12, color: empty ? AppColors.muted : AppColors.text)),
      ],
    );
  }
}
