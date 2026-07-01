import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import 'race_screen.dart';

class CountdownScreen extends StatefulWidget {
  final Room room;
  const CountdownScreen({super.key, required this.room});
  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  int n = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      setState(() => n--);
      if (n < 0) {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => RaceScreen(room: widget.room)),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: const Alignment(0, -0.15), radius: 0.9, colors: [AppColors.tint(0.16), AppColors.bg]),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const Text('추격 개시', style: TextStyle(letterSpacing: 3, color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 26),
              Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.coralA(.45), width: 2),
                  boxShadow: [BoxShadow(color: AppColors.coralA(.35), blurRadius: 80, spreadRadius: -8)],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                  child: Text(
                    n > 0 ? '$n' : 'GO',
                    key: ValueKey(n),
                    textAlign: TextAlign.center,
                    // 라인박스 위/아래 여백 제거 → 원 정중앙. 모노 대신 일반 볼드(단일 글자 중앙 정확).
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: TextStyle(
                      fontSize: n > 0 ? 96 : 64,
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
                TextSpan(text: 'GPS 위치 확보됨 · 좌표 미전송', style: TextStyle(fontSize: 12, color: AppColors.text)),
              ])),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
