import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock.dart';
import '../features/race/race_controller.dart';
import '../features/race/race_models.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

const double _rowH = 70;

/// 경주 화면. [roomId]+[userId] 가 있으면 '/race' 소켓 실연동(LiveRaceView),
/// 없으면 기존 목업 데모(카운트다운 데모 진입용)를 렌더한다.
class RaceScreen extends StatelessWidget {
  final Room room;
  final int? roomId;
  final int? userId;
  const RaceScreen({super.key, required this.room, this.roomId, this.userId});

  @override
  Widget build(BuildContext context) {
    final rid = roomId, uid = userId;
    if (rid != null && uid != null) {
      return LiveRaceView(roomId: rid, userId: uid);
    }
    return _MockRaceScreen(room: room);
  }
}

// ══════════════════════════════════════════════════════════════════════
// 실연동 경주 화면 (S3-7/8/9/10)
// ══════════════════════════════════════════════════════════════════════

class LiveRaceView extends ConsumerStatefulWidget {
  final int roomId;
  final int userId;
  const LiveRaceView({super.key, required this.roomId, required this.userId});

  @override
  ConsumerState<LiveRaceView> createState() => _LiveRaceViewState();
}

class _LiveRaceViewState extends ConsumerState<LiveRaceView> {
  Timer? _ticker;
  bool _navigatedToResult = false;
  int? _lastMyRank;
  bool _wasFinished = false;

  RaceArgs get _args => (roomId: widget.roomId, userId: widget.userId);

  @override
  void initState() {
    super.initState();
    // 남은시간(서버시계 기준)을 매초 다시 그린다 — 로컬 드리프트 누적 없이 재계산.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onStateChange(RaceState? prev, RaceState next) {
    // 햅틱(S3-10) — 내 완주 / 순위 상승 / 경주 종료.
    final myRank = next.myEntry(widget.userId)?.rank;
    // 완주 판정은 경쟁조건 안전한 OR(스냅샷 finished || runnerFinished(내) || 로컬 목표도달).
    final myFinished = next.isFinishedFor(widget.userId);
    final prevFinished = prev?.isFinishedFor(widget.userId) ?? false;
    if (myFinished && !prevFinished) {
      HapticFeedback.heavyImpact();
    } else if (myRank != null && _lastMyRank != null && myRank < _lastMyRank!) {
      HapticFeedback.lightImpact(); // 순위 역전(상승)
    }
    if (myRank != null) _lastMyRank = myRank;

    // 경주 종료 → 결과 화면(S3-7). raceFinished 가 최종 leaderboard 보다 먼저 와도
    // OR 판정으로 완주자를 DNF 로 오분류하지 않는다.
    if (next.raceFinished && !_wasFinished) {
      _wasFinished = true;
      HapticFeedback.heavyImpact();
      _goResult(finished: myFinished);
    }
  }

  void _goResult({required bool finished}) {
    if (_navigatedToResult || !mounted) return;
    _navigatedToResult = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(dnf: !finished)),
    );
  }

  Future<void> _confirmQuit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('그만둘까요?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text(
            '지금 그만두면 미완주(DNF)로 기록돼요.\n완주 보너스를 받지 못해요.',
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('계속 뛰기', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('그만두기',
                style: TextStyle(color: AppColors.alert, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(raceControllerProvider(_args).notifier).quit();
      _goResult(finished: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(raceControllerProvider(_args), _onStateChange);
    final s = ref.watch(raceControllerProvider(_args));
    final snap = s.snapshot;

    return Scaffold(
      body: SafeArea(
        child: snap == null
            ? _loading(s)
            : _content(context, s, snap),
      ),
    );
  }

  Widget _loading(RaceState s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: AppColors.coral, strokeWidth: 2.4),
          ),
          const SizedBox(height: 18),
          Muted(
            s.disconnected ? '연결 대기 중…' : '경주 준비 중…',
            size: 13,
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, RaceState s, LeaderboardSnapshot snap) {
    final goalKm = snap.goal.targetDistance;
    final runners = snap.runners; // 거리 내림차순
    final myEntry = s.myEntry(widget.userId);
    final myRank = myEntry?.rank; // 1-based
    // 내 표시 거리 = 로컬 트래커(끊김 중에도 계속)와 서버 중 큰 값.
    final myKm = max(myEntry?.distanceKm ?? 0.0, s.myDistanceKm);
    final ahead = (myRank != null && myRank > 1)
        ? runners.firstWhere((r) => r.rank == myRank - 1, orElse: () => runners.first)
        : null;
    final runningCount =
        runners.where((r) => r.status == RunnerStatus.running).length;

    final remainSec = s.clock.remainingSeconds(snap.deadlineMs);

    return Column(
      children: [
        _missionBar(goalKm, remainSec),
        Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            color: AppColors.coralA(.3)),
        if (s.disconnected) _banner(
          icon: Icons.wifi_off,
          text: '연결 끊김 — 내 거리는 로컬 GPS로 계속 측정 중, 상대 순위 동기화 대기…',
          color: AppColors.coral,
        ),
        if (s.gps == GpsSignal.weak)
          _banner(
            icon: Icons.gps_not_fixed,
            text: 'GPS 신호가 약해요 — 열린 하늘 아래로 이동하면 정확해져요.',
            color: AppColors.alert,
          )
        else if (s.gps == GpsSignal.none)
          _banner(
            icon: Icons.gps_off,
            text: 'GPS 위치 확보 중…',
            color: AppColors.muted,
          ),
        if (runningCount == 1 && runners.length > 1)
          _banner(
            icon: Icons.flag,
            text: '마지막 주자만 남았어요 — 완주하면 경주가 종료돼요.',
            color: AppColors.done,
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final r in runners)
                  _row(r, goalKm, isMe: r.userId == widget.userId,
                      isTarget: ahead != null && r.userId == ahead.userId,
                      displayKm: r.userId == widget.userId ? myKm : r.distanceKm),
              ],
            ),
          ),
        ),
        _statStrip(myKm, ahead, snap, s),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          child: AppButton('그만두기 (DNF)',
              variant: BtnVariant.alert, onTap: _confirmQuit),
        ),
      ],
    );
  }

  Widget _missionBar(double goalKm, int remainSec) {
    final m = remainSec ~/ 60, sec = remainSec % 60;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.alert, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('추격 중 · ${goalKm.toStringAsFixed(1)}km',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.coral)),
              ]),
              Text('$m:${sec.toString().padLeft(2, '0')}',
                  style: numStyle(size: 19, color: AppColors.alert, w: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          const Muted('남은 시간 · 실시간 순위', size: 11),
        ],
      ),
    );
  }

  Widget _banner(
      {required IconData icon, required String text, required Color color}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.tint(),
        borderRadius: BorderRadius.circular(R.sm),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Muted(text, size: 11, color: color)),
      ]),
    );
  }

  Widget _statStrip(
      double myKm, LeaderboardEntry? ahead, LeaderboardSnapshot snap, RaceState s) {
    // 페이스 = 경과시간 / 내 거리(분/km). 거리 미미하면 '—'.
    final elapsedMs = s.clock.nowMs() - snap.startedAtMs;
    String pace = "—'--\"";
    if (myKm > 0.05 && elapsedMs > 0) {
      final secPerKm = (elapsedMs / 1000) / myKm;
      final pm = secPerKm ~/ 60, ps = (secPerKm % 60).round();
      pace = "$pm'${ps.toString().padLeft(2, '0')}\"";
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.tint(),
        borderRadius: BorderRadius.circular(R.sm),
        border: Border.all(color: AppColors.coralA(.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Muted('타겟까지 ', size: 12),
            Text(
              ahead == null
                  ? '선두 유지'
                  : '+${(ahead.distanceKm - myKm).clamp(0, 999).toStringAsFixed(2)}km',
              style: numStyle(
                  size: 13,
                  color: ahead == null ? AppColors.coral : AppColors.alert),
            ),
          ]),
          Row(children: [
            const Muted('내 페이스 ', size: 12),
            Text(pace, style: numStyle(size: 13, color: AppColors.coral)),
          ]),
        ],
      ),
    );
  }

  Widget _row(LeaderboardEntry r, double goalKm,
      {required bool isMe, required bool isTarget, required double displayKm}) {
    final done = r.status == RunnerStatus.finished;
    final dnf = r.status == RunnerStatus.dnf;
    Color border = AppColors.line;
    Color barColor = const Color(0xFFAEB4BC);
    List<BoxShadow>? shadow;
    Color? bg;
    if (isMe) {
      border = AppColors.coral;
      bg = AppColors.tint();
      barColor = AppColors.coral;
      shadow = [
        BoxShadow(
            color: AppColors.coralA(.32),
            blurRadius: 28,
            spreadRadius: -14,
            offset: const Offset(0, 10))
      ];
    } else if (isTarget) {
      border = AppColors.alert;
      barColor = AppColors.alert;
    }
    if (done) barColor = AppColors.done;

    final color = _runnerColor(r.userId, isMe);
    final label = isMe ? '나' : '러너 ${r.rank}';

    return AnimatedPositioned(
      key: ValueKey(r.userId),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      top: (r.rank - 1) * _rowH,
      left: 0,
      right: 0,
      height: _rowH - 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: bg ?? AppColors.panel,
          borderRadius: BorderRadius.circular(R.r),
          border: Border.all(color: border),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            SizedBox(
                width: 18,
                child: Text('${r.rank}',
                    textAlign: TextAlign.center,
                    style: numStyle(
                        size: 14,
                        color: isMe ? AppColors.coral : AppColors.muted))),
            const SizedBox(width: 11),
            Avatar(isMe ? '나' : '${r.rank}', color, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: const Color(0xFF0D1016),
                          border: Border.all(color: const Color(0xFF20242B))),
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 700),
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            goalKm <= 0 ? 0 : (displayKm / goalKm).clamp(0, 1).toDouble(),
                        child: Container(
                            decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${displayKm.toStringAsFixed(2)}km',
                    style: numStyle(size: 14, w: FontWeight.w800)),
                const SizedBox(height: 2),
                if (done)
                  const Text('🏁 완주',
                      style: TextStyle(fontSize: 11, color: AppColors.done))
                else if (dnf)
                  const Text('DNF',
                      style: TextStyle(fontSize: 11, color: AppColors.alert))
                else
                  Text(r.rank == 1 ? '선두' : '${r.rank}위',
                      style: TextStyle(
                          fontSize: 11,
                          color: r.rank == 1 ? AppColors.coral : AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _runnerColor(int userId, bool isMe) {
    if (isMe) return AppColors.coral;
    const palette = [
      AppColors.a3,
      AppColors.a5,
      AppColors.a4,
      AppColors.a1,
      AppColors.a2
    ];
    return palette[userId % palette.length];
  }
}

// ══════════════════════════════════════════════════════════════════════
// 목업 데모 경주 화면(기존) — 카운트다운 데모 진입용. roomId/userId 미지정 시.
// ══════════════════════════════════════════════════════════════════════

class _MockRaceScreen extends StatefulWidget {
  final Room room;
  const _MockRaceScreen({required this.room});
  @override
  State<_MockRaceScreen> createState() => _MockRaceScreenState();
}

class _MockRaceScreenState extends State<_MockRaceScreen> {
  static const double _target = 5.0;
  late List<RaceRunner> runners;
  int remain = 18 * 60 + 42;
  bool discon = false;
  Timer? _t;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    runners = Mock.raceRunners();
    _recomputeRanks();
    _t = Timer.periodic(const Duration(milliseconds: 850), (_) {
      setState(() {
        for (final r in runners) {
          if (r.km < _target) {
            r.km = min(_target, r.km + r.base * (0.55 + _rng.nextDouble() * 0.9));
          }
        }
        remain = max(0, remain - 3);
        _recomputeRanks();
      });
    });
  }

  void _recomputeRanks() {
    final sorted = [...runners]..sort((a, b) => b.km.compareTo(a.km));
    for (var i = 0; i < sorted.length; i++) {
      sorted[i].rank = i;
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _clock() {
    final m = remain ~/ 60, s = remain % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  RaceRunner get _me => runners.firstWhere((r) => r.isMe);

  @override
  Widget build(BuildContext context) {
    final sorted = [...runners]..sort((a, b) => b.km.compareTo(a.km));
    final me = _me;
    final target = me.rank == 0 ? null : sorted[me.rank - 1];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.alert, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        const Text('추격 중 · 5.0km', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.coral)),
                      ]),
                      Text(_clock(), style: numStyle(size: 19, color: AppColors.alert, w: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Muted('남은 시간 · 실시간 순위', size: 11),
                ],
              ),
            ),
            Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 18), color: AppColors.coralA(.3)),
            if (discon)
              Container(
                margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.tint(),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: AppColors.coralA(.35)),
                ),
                child: const Muted('⚠️ 연결 끊김 — 내 거리는 로컬 GPS로 계속 측정 중, 상대 순위 동기화 대기…',
                    size: 11, color: AppColors.coral),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final r in runners) _row(r, r == target),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.tint(),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: AppColors.coralA(.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Muted('타겟까지 ', size: 12),
                    Text(
                      target == null ? '선두 유지' : '+${(target.km - me.km).toStringAsFixed(2)}km',
                      style: numStyle(size: 13, color: target == null ? AppColors.coral : AppColors.alert),
                    ),
                  ]),
                  Row(children: [
                    const Muted('내 페이스 ', size: 12),
                    Text("5'30\"", style: numStyle(size: 13, color: AppColors.coral)),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(children: [
                Expanded(child: AppButton('연결끊김 시뮬', variant: BtnVariant.ghost, height: 42, fontSize: 12, onTap: () => setState(() => discon = !discon))),
                const SizedBox(width: 9),
                Expanded(child: AppButton('완주 → 결과', variant: BtnVariant.outline, height: 42, fontSize: 12, onTap: () {
                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResultScreen()));
                })),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              child: AppButton('그만두기 (DNF)', variant: BtnVariant.alert, onTap: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ResultScreen(dnf: true)));
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(RaceRunner r, bool isTarget) {
    final done = r.km >= _target;
    Color border = AppColors.line;
    Color barColor = const Color(0xFFAEB4BC);
    List<BoxShadow>? shadow;
    Color? bg;
    if (r.isMe) {
      border = AppColors.coral;
      bg = AppColors.tint();
      barColor = AppColors.coral;
      shadow = [BoxShadow(color: AppColors.coralA(.32), blurRadius: 28, spreadRadius: -14, offset: const Offset(0, 10))];
    } else if (isTarget) {
      border = AppColors.alert;
      barColor = AppColors.alert;
    }
    if (done) barColor = AppColors.done;

    final gap = done
        ? null
        : (r.rank == 0 ? '선두' : 'Δ ${(([...runners]..sort((a, b) => b.km.compareTo(a.km)))[r.rank - 1].km - r.km).toStringAsFixed(2)}km');

    return AnimatedPositioned(
      key: ValueKey(r.id),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      top: r.rank * _rowH,
      left: 0,
      right: 0,
      height: _rowH - 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: bg ?? AppColors.panel,
          borderRadius: BorderRadius.circular(R.r),
          border: Border.all(color: border),
          boxShadow: shadow,
        ),
        child: Row(
          children: [
            SizedBox(width: 18, child: Text('${r.rank + 1}', textAlign: TextAlign.center, style: numStyle(size: 14, color: r.isMe ? AppColors.coral : AppColors.muted))),
            const SizedBox(width: 11),
            Avatar(r.name.characters.first, r.color, size: 34),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    if (r.isMe) ...[
                      const SizedBox(width: 7),
                      const Text('나', style: TextStyle(fontSize: 11, color: AppColors.coral, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: const Color(0xFF0D1016), border: Border.all(color: const Color(0xFF20242B))),
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 700),
                        alignment: Alignment.centerLeft,
                        widthFactor: (r.km / _target).clamp(0, 1).toDouble(),
                        child: Container(decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(20))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${r.km.toStringAsFixed(2)}km', style: numStyle(size: 14, w: FontWeight.w800)),
                const SizedBox(height: 2),
                done
                    ? const Text('🏁 완주', style: TextStyle(fontSize: 11, color: AppColors.done))
                    : Text(gap!, style: TextStyle(fontSize: 11, color: r.rank == 0 ? AppColors.coral : AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
