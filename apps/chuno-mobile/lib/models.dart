import 'package:flutter/material.dart';

enum RoomStatus { soon, open, live }

class Room {
  final String name;
  final double targetKm;
  final int limitMin;
  final int cur;
  final int max;
  final String startInfo; // 예: "06:00 시작"
  final String? countdown; // 예: "12분 후" (없으면 표시 안 함)
  final RoomStatus status;
  const Room({
    required this.name,
    required this.targetKm,
    required this.limitMin,
    required this.cur,
    required this.max,
    required this.startInfo,
    this.countdown,
    required this.status,
  });
}

class Participant {
  final String name;
  final Color color;
  final bool isMe;
  final bool host;
  const Participant(this.name, this.color, {this.isMe = false, this.host = false});
}

/// 경주 러너 — km 는 진행 중 변한다(가변).
class RaceRunner {
  final String id;
  final String name;
  final bool isMe;
  final Color color;
  final double base; // tick 당 기본 증가량
  double km;
  int rank = 0;
  RaceRunner({
    required this.id,
    required this.name,
    required this.color,
    required this.base,
    this.isMe = false,
    this.km = 0,
  });
}

