import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../features/rooms/room_models.dart';
import '../features/rooms/room_providers.dart';
import '../models.dart' as mock;
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'create_room_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomListProvider);
    final filters = ref.watch(roomFiltersProvider);

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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: _Filters(filters: filters, ref: ref),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.coral,
                backgroundColor: AppColors.panel,
                onRefresh: () => ref.refresh(roomListProvider.future),
                child: roomsAsync.when(
                  data: (rooms) => _RoomList(rooms: rooms),
                  loading: () => const _RoomSkeleton(),
                  error: (e, _) => _RoomError(
                    message: _msg(e),
                    onRetry: () => ref.invalidate(roomListProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 24,
          child: GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
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

  static String _msg(Object e) {
    final s = e.toString();
    // AppException.toString() 은 'Type(status): message' — message 만 노출.
    final idx = s.indexOf(': ');
    return idx >= 0 ? s.substring(idx + 2) : s;
  }
}

/// 거리·제한시간 필터 칩(레인지바 → 서버 쿼리 반영) + 임박순 정렬 표시.
class _Filters extends StatelessWidget {
  final RoomFilters filters;
  final WidgetRef ref;
  const _Filters({required this.filters, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pickRange(
              context,
              title: '목표 거리',
              unit: 'km',
              lo: kDistanceMin,
              hi: kDistanceMax,
              divisions: kDistanceMax - kDistanceMin,
              current: RangeValues(filters.distanceMin.toDouble(), filters.distanceMax.toDouble()),
              onApply: (mn, mx) => ref.read(roomFiltersProvider.notifier).setDistance(mn, mx),
            ),
            child: PillChip('${filters.distanceLabel} ▾', active: filters.distanceActive),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pickRange(
              context,
              title: '제한 시간',
              unit: '분',
              lo: kLimitMin,
              hi: kLimitMax,
              divisions: (kLimitMax - kLimitMin) ~/ kLimitStep,
              current: RangeValues(filters.limitMin.toDouble(), filters.limitMax.toDouble()),
              onApply: (mn, mx) => ref.read(roomFiltersProvider.notifier).setLimit(mn, mx),
            ),
            child: PillChip('${filters.limitLabel} ▾', active: filters.limitActive),
          ),
          const SizedBox(width: 8),
          // 정렬은 임박순 고정(서버 sort=scheduledStartOn&order=ASC).
          const PillChip('임박순', active: true),
        ],
      ),
    );
  }

  /// 가로 레인지바 바텀시트로 min/max 범위를 고른다.
  /// '적용'은 현재 값, '초기화'는 전체 범위(필터 미적용)로 pop → onApply.
  Future<void> _pickRange(
    BuildContext context, {
    required String title,
    required String unit,
    required int lo,
    required int hi,
    required int divisions,
    required RangeValues current,
    required void Function(int min, int max) onApply,
  }) async {
    final picked = await showModalBottomSheet<RangeValues>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.r)),
      ),
      builder: (ctx) => _RangeSheet(
        title: title,
        unit: unit,
        lo: lo.toDouble(),
        hi: hi.toDouble(),
        divisions: divisions,
        initial: current,
      ),
    );
    if (picked != null) onApply(picked.start.round(), picked.end.round());
  }
}

/// 필터 레인지바 바텀시트 — 상단 값 라벨, 코랄 활성 트랙, 하단 '초기화'·'적용'.
class _RangeSheet extends StatefulWidget {
  final String title;
  final String unit;
  final double lo;
  final double hi;
  final int divisions;
  final RangeValues initial;
  const _RangeSheet({
    required this.title,
    required this.unit,
    required this.lo,
    required this.hi,
    required this.divisions,
    required this.initial,
  });

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late RangeValues _values = widget.initial;

  @override
  Widget build(BuildContext context) {
    final s = _values.start.round();
    final e = _values.end.round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text('$s – $e ${widget.unit}', style: numStyle(size: 14, color: AppColors.coral)),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.coral,
                inactiveTrackColor: AppColors.line,
                thumbColor: AppColors.coral,
                overlayColor: AppColors.coralA(.18),
                valueIndicatorColor: AppColors.coral,
                trackHeight: 4,
                rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: RangeSlider(
                values: _values,
                min: widget.lo,
                max: widget.hi,
                divisions: widget.divisions,
                labels: RangeLabels('$s', '$e'),
                onChanged: (v) => setState(() => _values = v),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: AppButton('초기화',
                    variant: BtnVariant.ghost,
                    height: 46,
                    fontSize: 14,
                    onTap: () => Navigator.of(context).pop(RangeValues(widget.lo, widget.hi))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton('적용',
                    variant: BtnVariant.primary,
                    height: 46,
                    fontSize: 14,
                    onTap: () => Navigator.of(context).pop(_values)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 백엔드가 "이미 참여 중" 을 나타내는 정확한 message(POST /rooms/:id/join, 400).
/// 백엔드가 멤버십 플래그를 내려주지 않아 이 문자열 매칭에 의존한다(계약 한계).
const String _kAlreadyJoinedMessage = '이미 참여 중인 방입니다.';

class _RoomList extends ConsumerWidget {
  final List<RoomModel> rooms;
  const _RoomList({required this.rooms});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rooms.isEmpty) return const _RoomEmpty();
    final liveCount = rooms.where((r) => r.status == RoomStatus.live).length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
      children: [
        if (liveCount > 0) ...[
          Panel(
            color: AppColors.alertA(.10),
            border: Border.all(color: AppColors.alertA(.30)),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(children: [
              const _Dot(AppColors.alert),
              const SizedBox(width: 9),
              const Text('LIVE', style: TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 8),
              Muted('추격전 $liveCount건 진행 중', size: 12),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        for (final room in rooms) ...[
          _RoomCard(room, onTap: () => _open(context, ref, room)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// 방카드 참가/관전 액션.
  /// - live: 관전은 준비 중(참가 대상 아님).
  /// - 방장 자기 방: 이미 참가 상태 → join 없이 바로 로비.
  /// - 그 외: `POST /rooms/:id/join` 후 성공/이미참여 시 로비, 나머지는 실패 안내.
  Future<void> _open(BuildContext context, WidgetRef ref, RoomModel room) async {
    if (room.status == RoomStatus.live) {
      comingSoon(context, '관전은 준비 중이에요');
      return;
    }
    if (room.isHost) {
      _pushLobby(Navigator.of(context), room);
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const _JoinLoading(),
    );
    try {
      await ref.read(roomRepositoryProvider).join(room.id);
      ref.invalidate(roomListProvider);
      if (!context.mounted) return;
      navigator.pop(); // 로딩 닫기
      _pushLobby(navigator, room);
    } on AppException catch (e) {
      if (!context.mounted) return;
      navigator.pop();
      // 이미 참여 중이면 실패로 보지 않고 바로 로비로.
      if (e.message.trim() == _kAlreadyJoinedMessage) {
        _pushLobby(navigator, room);
        return;
      }
      _snack(messenger, e.message);
    } catch (_) {
      if (!context.mounted) return;
      navigator.pop();
      _snack(messenger, '참가하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }

  void _pushLobby(NavigatorState navigator, RoomModel room) {
    navigator.push(MaterialPageRoute(
      builder: (_) => LobbyScreen(room: _toMock(room), roomId: room.id),
    ));
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

  /// 로비(목업 UI)로 넘길 표시용 mock.Room 변환. 실 식별자는 roomId 로 별도 전달.
  static mock.Room _toMock(RoomModel r) => mock.Room(
        name: r.name,
        targetKm: r.targetDistance.toDouble(),
        limitMin: r.limitMinutes,
        cur: r.currentParticipantsCount,
        max: r.maxParticipants,
        startInfo: r.startLabel,
        countdown: r.countdownLabel,
        status: switch (r.status) {
          RoomStatus.starting => mock.RoomStatus.soon,
          RoomStatus.live => mock.RoomStatus.live,
          _ => mock.RoomStatus.open,
        },
      );
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;
  const _RoomCard(this.room, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (tag, tagBg, tagFg) = switch (room.status) {
      RoomStatus.starting => ('곧 시작', AppColors.coralA(.18), AppColors.coral),
      RoomStatus.live => ('LIVE', AppColors.alertA(.15), AppColors.alert),
      RoomStatus.recruiting => ('모집중', const Color(0xFF2B323A), const Color(0xFF9AA3AD)),
      RoomStatus.finished => ('종료', const Color(0xFF2B323A), const Color(0xFF9AA3AD)),
      RoomStatus.cancelled => ('취소', const Color(0xFF2B323A), const Color(0xFF9AA3AD)),
    };
    final isLive = room.status == RoomStatus.live;
    final action = AppButton(
      isLive
          ? '관전'
          : room.isHost
              ? '입장'
              : '참가',
      variant: room.status == RoomStatus.starting ? BtnVariant.primary : BtnVariant.ghost,
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
              children: [
                Expanded(
                  child: Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                if (room.isHost) ...[
                  const SizedBox(width: 8),
                  Tag('👑 내 방', bg: AppColors.coralA(.18), fg: AppColors.coral),
                ],
                const SizedBox(width: 8),
                Tag(tag, bg: tagBg, fg: tagFg),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              children: [
                TextSpan(text: '목표 ${room.targetDistance}km · 제한 ${room.limitMinutes}분 · '),
                TextSpan(
                  text: '${room.currentParticipantsCount}/${room.maxParticipants}명',
                  style: const TextStyle(color: AppColors.text),
                ),
              ],
            )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(children: [
                    Flexible(child: Muted('⏰ ${room.startLabel}', size: 12)),
                    if (room.countdownLabel != null) ...[
                      const SizedBox(width: 8),
                      Tag(room.countdownLabel!, bg: AppColors.coralA(.18), fg: AppColors.coral),
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

/// 빈 목록 분기 — 스크롤 가능(당겨서 새로고침 유지).
class _RoomEmpty extends StatelessWidget {
  const _RoomEmpty();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 60, 18, 100),
      children: const [
        Center(
          child: Column(
            children: [
              Text('🏃', style: TextStyle(fontSize: 40)),
              SizedBox(height: 14),
              Text('열린 추격전이 없어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Muted('＋ 버튼으로 새 추격전을 만들어 보세요', size: 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// 로딩 스켈레톤 — 카드 3장 형태의 플레이스홀더.
class _RoomSkeleton extends StatelessWidget {
  const _RoomSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
      children: [
        for (var i = 0; i < 3; i++) ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(160, 15),
                const SizedBox(height: 12),
                _bar(200, 12),
                const SizedBox(height: 16),
                _bar(110, 12),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(R.sm)),
      );
}

/// 목록 조회 실패 — 크래시 없이 재시도.
class _RoomError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RoomError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 60, 18, 100),
      children: [
        Center(
          child: Column(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 14),
              Muted(message, size: 13, color: AppColors.text),
              const SizedBox(height: 12),
              AppButton('다시 시도', variant: BtnVariant.outline, expand: false, height: 40, fontSize: 13, onTap: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}

/// 참가 요청 중 표시하는 모달 로딩(코랄 스피너). 백드롭 탭으로 닫히지 않음.
class _JoinLoading extends StatelessWidget {
  const _JoinLoading();
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

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
