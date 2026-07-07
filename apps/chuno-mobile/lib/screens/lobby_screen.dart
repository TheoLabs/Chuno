import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../features/rooms/lobby_socket_controller.dart';
import '../features/rooms/room_models.dart' hide RoomStatus;
import '../features/rooms/room_models.dart' as rm;
import '../features/rooms/room_providers.dart';
import '../features/rooms/room_repository.dart';
import '../features/users/user_providers.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'countdown_screen.dart';
import 'race_screen.dart';
import 'server_countdown_screen.dart';

class LobbyScreen extends ConsumerWidget {
  /// 표시용 폴백(생성/목록에서 넘겨받은 값). [roomId] 가 있으면 상세 조회가 우선한다.
  final Room room;

  /// 서버 방 id. 있으면 `GET /rooms/:id` 상세를 로드해 렌더한다.
  final int? roomId;
  const LobbyScreen({super.key, required this.room, this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = roomId;
    // roomId 없으면(목록 미연동 경로) 폴백 목업으로 즉시 렌더(소켓 미사용).
    if (id == null) {
      return _Scaffold(view: _LobbyView.fromMock(room), room: room);
    }
    // 소켓 실시간 — 진입 시 연결·joinRoom, 이탈 시 leaveRoom·정리(autoDispose).
    final socket = ref.watch(lobbySocketProvider(id));
    ref.listen(lobbySocketProvider(id), (prev, next) {
      _handleSocket(context, ref, id, prev, next);
    });
    final disconnected = socket.connection == LobbyConnection.disconnected;
    final detail = ref.watch(roomDetailProvider(id));
    return detail.when(
      data: (r) => _Scaffold(
          view: _LobbyView.fromModel(r), room: room, roomId: id, disconnected: disconnected),
      loading: () => _Scaffold(
          view: _LobbyView.fromMock(room), room: room, roomId: id, loading: true, disconnected: disconnected),
      error: (_, _) => _Scaffold(
        view: _LobbyView.fromMock(room),
        room: room,
        roomId: id,
        disconnected: disconnected,
        onRetry: () => ref.invalidate(roomDetailProvider(id)),
      ),
    );
  }

  /// 소켓 상태 변화 반응 — 방 취소(홈 복귀)·상태전환(STARTING 카운트다운/LIVE 안내).
  void _handleSocket(
    BuildContext context,
    WidgetRef ref,
    int id,
    LobbySocketState? prev,
    LobbySocketState next,
  ) {
    if (next.cancelled && (prev == null || !prev.cancelled)) {
      _onRoomCancelled(context);
      return;
    }
    if (next.status != prev?.status) {
      if (next.status == rm.RoomStatus.starting) {
        _onStarting(context, ref, id);
      } else if (next.status == rm.RoomStatus.live) {
        _onLive(context, ref, id);
      }
    }
  }

  /// STARTING(예약 T−10s) → 서버시계 동기 카운트다운 화면으로 전환.
  /// 0 도달(LIVE) 시 onLive 로 경주 화면(실연동)에 진입한다.
  void _onStarting(BuildContext context, WidgetRef ref, int id) {
    final detail = ref.read(roomDetailProvider(id)).valueOrNull;
    final clock = ref.read(lobbySocketProvider(id)).clock;
    final userId = _myUserId(ref);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => ServerCountdownScreen(
        targetEpochMs: detail?.scheduledStartEpochMs,
        clock: clock,
        onLive: userId == null ? null : () => _enterRace(ctx, id, userId),
      ),
    ));
  }

  /// LIVE(출발) — 카운트다운 없이 즉시 LIVE 통보 시. 경주 화면(실연동) 진입.
  void _onLive(BuildContext context, WidgetRef ref, int id) {
    if (!context.mounted) return;
    final userId = _myUserId(ref);
    if (userId == null) {
      // 사용자 식별 불가(비정상) — 안내만.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('출발! 경주 화면을 열 수 없어요'),
          duration: Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel2,
        ));
      return;
    }
    _enterRace(context, id, userId);
  }

  /// 경주 화면(LiveRaceView) 진입 — 카운트다운/로비 위로 push.
  void _enterRace(BuildContext context, int roomId, int userId) {
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => RaceScreen(room: room, roomId: roomId, userId: userId),
    ));
  }

  /// 내 사용자 id(정수). meProvider 미로딩/비정수면 null.
  int? _myUserId(WidgetRef ref) {
    final me = ref.read(meProvider).valueOrNull;
    return int.tryParse(me?.id ?? '');
  }

  /// 방 취소(roomCancelled) → 안내 다이얼로그 후 홈(루트) 복귀.
  Future<void> _onRoomCancelled(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('방이 취소되었어요', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text('방장이 방을 취소했거나 시작 인원이 부족해요.', style: TextStyle(fontSize: 14, color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    navigator.popUntil((r) => r.isFirst); // 홈(루트)으로 복귀
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('방이 취소되었습니다'),
        duration: Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel2,
      ));
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

  /// 모집중(RECRUITING) 여부 — 방삭제/나가기 액션 활성 조건.
  final bool isRecruiting;

  const _LobbyView({
    required this.name,
    required this.metaLabel,
    required this.startBig,
    required this.startCaption,
    required this.cur,
    required this.max,
    required this.isHost,
    required this.isRecruiting,
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
      // room_models.RoomStatus 는 이 파일에서 hide 라 wire 문자열로 비교.
      isRecruiting: r.status.wire == 'recruiting',
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
      isRecruiting: r.status != RoomStatus.live,
    );
  }
}

class _Scaffold extends ConsumerWidget {
  final _LobbyView view;
  final Room room; // 카운트다운 데모 진입용(기존 목업 플로우 유지)
  final int? roomId; // 서버 방 id — 있어야 삭제/나가기 실 API 호출.
  final bool loading;

  /// 소켓 끊김 표시(재접속 중). true 면 상단에 안내 배너를 노출한다.
  final bool disconnected;
  final VoidCallback? onRetry;
  const _Scaffold({required this.view, required this.room, this.roomId, this.loading = false, this.disconnected = false, this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                if (disconnected) ...[
                  Panel(
                    color: AppColors.panel2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: const Row(children: [
                      Icon(Icons.wifi_off, size: 16, color: AppColors.muted),
                      SizedBox(width: 8),
                      Expanded(child: Muted('연결이 끊겼어요 · 다시 연결 중…', size: 12)),
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
          // 방장 = 방 삭제, 비방장 = 나가기(둘 다 모집중일 때만). RECRUITING 이 아니면 미노출.
          if (view.isRecruiting)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
              child: view.isHost
                  ? AppButton('방 삭제', variant: BtnVariant.ghost, onTap: () => _confirmDelete(context, ref))
                  : AppButton('나가기', variant: BtnVariant.alert, onTap: () => _confirmLeave(context, ref)),
            )
          else
            const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 방장 방 삭제 → 확인 → 로딩 → DELETE /rooms/:id → 홈 복귀/실패 안내.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    await _runRoomAction(
      context,
      ref,
      confirmTitle: '방 삭제',
      confirmMessage: '방을 삭제할까요?\n참가자에게 취소가 안내됩니다.',
      confirmLabel: '삭제',
      action: (repo, id) => repo.delete(id),
      successMessage: '방이 삭제되었습니다',
      fallbackError: '방을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.',
    );
  }

  /// 참가자 나가기 → 확인 → 로딩 → DELETE /rooms/:id/leave → 홈 복귀/실패 안내.
  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    await _runRoomAction(
      context,
      ref,
      confirmTitle: '방 나가기',
      confirmMessage: '방에서 나갈까요?',
      confirmLabel: '나가기',
      action: (repo, id) => repo.leave(id),
      successMessage: '방에서 나갔습니다',
      fallbackError: '방에서 나가지 못했어요. 잠시 후 다시 시도해 주세요.',
    );
  }

  /// 삭제/나가기 공통 흐름 — 확인 다이얼로그 → 로딩 barrier → 실 API → 홈 복귀 + 스낵바.
  Future<void> _runRoomAction(
    BuildContext context,
    WidgetRef ref, {
    required String confirmTitle,
    required String confirmMessage,
    required String confirmLabel,
    required Future<void> Function(RoomRepository repo, int id) action,
    required String successMessage,
    required String fallbackError,
  }) async {
    final id = roomId;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // roomId 가 없으면(순수 목업 데모) 실 호출 없이 화면만 닫는다.
    if (id == null) {
      navigator.pop();
      return;
    }
    final repo = ref.read(roomRepositoryProvider);
    final ok = await _confirm(
      context,
      title: confirmTitle,
      message: confirmMessage,
      confirmLabel: confirmLabel,
    );
    if (!ok || !context.mounted) return;
    // 로딩 barrier — 완료까지 버튼 이중 탭을 차단한다.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const _ActionLoading(),
    );
    try {
      await action(repo, id);
      ref.invalidate(roomListProvider);
      if (!context.mounted) return;
      navigator.pop(); // 로딩 닫기
      navigator.popUntil((r) => r.isFirst); // 홈(루트)으로 복귀
      _snack(messenger, successMessage);
    } on AppException catch (e) {
      if (!context.mounted) return;
      navigator.pop();
      _snack(messenger, e.message);
    } catch (_) {
      if (!context.mounted) return;
      navigator.pop();
      _snack(messenger, fallbackError);
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _snack(ScaffoldMessengerState messenger, String msg) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel2,
      ));
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

/// 삭제/나가기 진행 중 전체 barrier 로딩(이중 탭 차단).
class _ActionLoading extends StatelessWidget {
  const _ActionLoading();
  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: Center(
        child: SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 3),
        ),
      ),
    );
  }
}
