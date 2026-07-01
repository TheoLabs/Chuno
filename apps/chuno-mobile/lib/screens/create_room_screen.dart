import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'lobby_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _name = TextEditingController(text: '5km 새벽 추격');
  final _limit = TextEditingController(text: '40');
  final _maxP = TextEditingController(text: '6');
  final _goals = <double>[3, 5, 10, 0]; // 0 = 커스텀
  int _goalIdx = 1;
  TimeOfDay _start = const TimeOfDay(hour: 6, minute: 0);

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _maxP.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start,
      builder: (ctx, child) => Theme(data: buildAppTheme(), child: child!),
    );
    if (picked != null) setState(() => _start = picked);
  }

  void _create() {
    final km = _goalIdx == 3 ? 5.0 : _goals[_goalIdx];
    final room = Room(
      name: _name.text.trim().isEmpty ? '새 추격전' : _name.text.trim(),
      targetKm: km,
      limitMin: int.tryParse(_limit.text) ?? 40,
      cur: 1,
      max: int.tryParse(_maxP.text) ?? 6,
      startInfo: '${_start.format(context)} 시작',
      status: RoomStatus.soon,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LobbyScreen(room: room)));
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
                _field('목표 거리', _segment(['3km', '5km', '10km', '커스텀'], _goalIdx, (i) => setState(() => _goalIdx = i))),
                _field('제한 시간', AppTextField(controller: _limit, keyboardType: TextInputType.number, suffixText: '분', digitsOnly: true)),
                _field('최대 인원', AppTextField(controller: _maxP, keyboardType: TextInputType.number, suffixText: '명', digitsOnly: true)),
                _field(
                  '시작 시각',
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(R.sm),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(children: [
                        Text('오늘 · ${_start.format(context)}', style: const TextStyle(fontSize: 14)),
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
                      TextSpan(text: '이면 방은 자동 삭제(경주 미성립).'),
                    ],
                  )),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            child: AppButton('방 만들기', onTap: _create),
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
