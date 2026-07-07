import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/rooms/server_clock.dart';
import '../theme/app_theme.dart';

/// 서버시계 동기 카운트다운(S2-9). STARTING(예약시각 T−10s) 진입 시 로비가 전환한다.
///
/// 남은 시간 = [targetEpochMs] − 서버now([clock] 오프셋 보정). 여러 기기가 각자
/// 로컬시계가 어긋나 있어도 서버 기준으로 거의 동시에 0(=LIVE/출발)이 된다.
/// 경주 화면은 Step3 경계라 0 도달 시 플레이스홀더로 출발만 표시한다.
class ServerCountdownScreen extends StatefulWidget {
  /// 출발 목표 epoch ms(= scheduledStartOn). null 이면 즉시 출발 표시.
  final int? targetEpochMs;

  /// 서버시각 오프셋 보정 시계.
  final ServerClock clock;

  /// LIVE 전환 콜백(플레이스홀더 대신 외부에서 처리하고 싶을 때).
  final VoidCallback? onLive;

  const ServerCountdownScreen({
    super.key,
    required this.targetEpochMs,
    this.clock = ServerClock.unsynced,
    this.onLive,
  });

  @override
  State<ServerCountdownScreen> createState() => _ServerCountdownScreenState();
}

class _ServerCountdownScreenState extends State<ServerCountdownScreen> {
  Timer? _t;
  late int _seconds;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    _seconds = _compute();
    if (_seconds <= 0) {
      _live = true;
    } else {
      // 100ms 틱으로 서버 기준 남은 초를 갱신(로컬 드리프트 누적 없이 매번 재계산).
      _t = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    }
  }

  int _compute() {
    final target = widget.targetEpochMs;
    if (target == null) return 0;
    return widget.clock.remainingSeconds(target);
  }

  void _tick() {
    final s = _compute();
    if (s != _seconds && mounted) {
      setState(() => _seconds = s);
      // 카운트다운 매 초 가벼운 진동(S3-10) — 3·2·1 리듬.
      if (s > 0) HapticFeedback.lightImpact();
    }
    if (s <= 0) {
      _t?.cancel();
      if (mounted && !_live) {
        HapticFeedback.heavyImpact(); // 출발 순간 강한 진동
        setState(() => _live = true);
        widget.onLive?.call();
      }
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final big = _live ? 'GO' : '$_seconds';
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.9,
            colors: [AppColors.tint(0.16), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(_live ? '출발' : '동시 출발 대기',
                    style: const TextStyle(
                        letterSpacing: 3, color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 26),
                Container(
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.coralA(.45), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.coralA(.35),
                          blurRadius: 80,
                          spreadRadius: -8)
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (c, a) => ScaleTransition(
                        scale: a, child: FadeTransition(opacity: a, child: c)),
                    child: Text(
                      big,
                      key: ValueKey(big),
                      textAlign: TextAlign.center,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      style: TextStyle(
                        fontSize: _live ? 64 : 96,
                        fontWeight: FontWeight.w800,
                        color: AppColors.coral,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text.rich(TextSpan(children: [
                  TextSpan(text: '● ', style: TextStyle(color: AppColors.done)),
                  TextSpan(
                      text: '서버시각 기준 · 좌표 미전송',
                      style: TextStyle(fontSize: 12, color: AppColors.text)),
                ])),
                if (_live) ...[
                  const SizedBox(height: 20),
                  const Text('경주 화면은 준비 중이에요',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('로비로 돌아가기',
                        style: TextStyle(color: AppColors.coral)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
