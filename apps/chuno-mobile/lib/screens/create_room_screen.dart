import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../features/rooms/room_providers.dart';
import '../models.dart' as mock;
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  final _name = TextEditingController(text: '5km 새벽 추격');
  final _limit = TextEditingController(text: '40');
  final _maxP = TextEditingController(text: '6');
  final _custom = TextEditingController(text: '7');
  final _goals = <int>[3, 5, 10, 0]; // 0 = 커스텀
  int _goalIdx = 1;
  late DateTime _startAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 기본값: 30분 뒤(미래) — 초는 0으로 정렬.
    final base = DateTime.now().add(const Duration(minutes: 30));
    _startAt = DateTime(base.year, base.month, base.day, base.hour, base.minute);
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _maxP.dispose();
    _custom.dispose();
    super.dispose();
  }

  int get _targetDistance =>
      _goalIdx == 3 ? (int.tryParse(_custom.text) ?? 0) : _goals[_goalIdx];

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startAt.isBefore(now) ? now : _startAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(data: buildAppTheme(), child: child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
      builder: (ctx, child) => Theme(data: buildAppTheme(), child: child!),
    );
    if (time == null) return;
    setState(() => _startAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _fmtWire(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}:00';
  }

  String _startLabel() {
    final d = _startAt;
    final today = DateTime.now();
    final sameDay = d.year == today.year && d.month == today.month && d.day == today.day;
    String p(int n) => n.toString().padLeft(2, '0');
    final day = sameDay ? '오늘' : '${d.month}/${d.day}';
    return '$day · ${p(d.hour)}:${p(d.minute)}';
  }

  /// 클라 검증(백엔드 도메인 가드와 일치). 위반 라벨 반환, 통과 시 null.
  String? _validate() {
    if (_name.text.trim().isEmpty) return '방 이름을 입력해 주세요.';
    if (_targetDistance < 1) return '목표 거리는 1km 이상이어야 해요.';
    if ((int.tryParse(_limit.text) ?? 0) < 10) return '제한 시간은 10분 이상이어야 해요.';
    if ((int.tryParse(_maxP.text) ?? 0) < 2) return '최대 인원은 2명 이상이어야 해요.';
    if (!_startAt.isAfter(DateTime.now())) return '시작 시각은 현재 이후여야 해요.';
    return null;
  }

  Future<void> _create() async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    final err = _validate();
    if (err != null) {
      _snack(messenger, err);
      return;
    }
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    final targetDistance = _targetDistance;
    final limitMinutes = int.parse(_limit.text);
    final maxParticipants = int.parse(_maxP.text);
    try {
      final id = await ref.read(roomRepositoryProvider).create(
            name: name,
            targetDistance: targetDistance,
            limitMinutes: limitMinutes,
            maxParticipants: maxParticipants,
            scheduledStartOn: _fmtWire(_startAt),
          );
      // 홈으로 돌아왔을 때 최신 목록 반영.
      ref.invalidate(roomListProvider);
      if (!mounted) return;
      _snack(messenger, '방을 만들었어요');
      // 방장으로 로비 진입(서버 방 id 전달). 로비 UI 는 목업이지만 id 는 보관.
      final room = mock.Room(
        name: name,
        targetKm: targetDistance.toDouble(),
        limitMin: limitMinutes,
        cur: 1,
        max: maxParticipants,
        startInfo: _startLabel(),
        status: mock.RoomStatus.soon,
      );
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => LobbyScreen(room: room, roomId: id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack(messenger, e is AppException ? e.message : '방을 만들지 못했어요.');
    }
  }

  void _snack(ScaffoldMessengerState messenger, String msg) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1600),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel2,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('방 만들기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              children: [
                _field('방 이름', AppTextField(controller: _name, hint: '방 이름을 입력', maxLength: 20)),
                _field(
                  '목표 거리',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _segment(['3km', '5km', '10km', '커스텀'], _goalIdx, (i) => setState(() => _goalIdx = i)),
                      if (_goalIdx == 3) ...[
                        const SizedBox(height: 10),
                        AppTextField(controller: _custom, keyboardType: TextInputType.number, suffixText: 'km', digitsOnly: true),
                      ],
                    ],
                  ),
                ),
                _field('제한 시간', AppTextField(controller: _limit, keyboardType: TextInputType.number, suffixText: '분', digitsOnly: true)),
                _field('최대 인원', AppTextField(controller: _maxP, keyboardType: TextInputType.number, suffixText: '명', digitsOnly: true)),
                _field(
                  '시작 시각',
                  GestureDetector(
                    onTap: _pickStart,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(R.sm),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(children: [
                        Text(_startLabel(), style: const TextStyle(fontSize: 14)),
                        const Spacer(),
                        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
                      ]),
                    ),
                  ),
                ),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: const Text.rich(TextSpan(
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                    children: [
                      TextSpan(text: '⚠️ 시작 시각에 '),
                      TextSpan(text: '2명 미만', style: TextStyle(color: AppColors.text)),
                      TextSpan(text: '이면 방은 자동 취소돼요(경주 미성립).'),
                    ],
                  )),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            child: AppButton(_submitting ? '만드는 중…' : '방 만들기', onTap: _submitting ? null : _create),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Muted(label, size: 12)),
            child,
          ],
        ),
      );

  Widget _segment(List<String> items, int active, ValueChanged<int> onTap) => Container(
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
