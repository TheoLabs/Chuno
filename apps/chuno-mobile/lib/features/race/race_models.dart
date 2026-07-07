/// '/race' 소켓 계약 매핑 모델(S3-7) — core-api `LeaderboardSnapshot`/`LeaderboardEntry` 대응.
///
/// 서버는 좌표를 받지 않고 거리(km)만 서버 권위로 집계한다. 클라는 표시만 한다.
library;

/// 러너 상태(core-api RunnerStatus enum).
enum RunnerStatus {
  running,
  finished,
  dnf, // 제한시간 경과 미완주
  disconnected;

  static RunnerStatus fromWire(String? s) => switch (s) {
        'running' => running,
        'finished' => finished,
        'dnf' => dnf,
        'disconnected' => disconnected,
        _ => running,
      };
}

/// 경주 상태(core-api RaceStatus enum).
enum RaceStatus {
  live,
  finished;

  static RaceStatus fromWire(String? s) =>
      s == 'finished' ? finished : live;
}

/// 리더보드 1행 — 거리 내림차순 순위, 서버 권위 거리.
class LeaderboardEntry {
  final int rank;
  final int userId;
  final double distanceKm;
  final RunnerStatus status;
  final int? finishedAtMs; // epoch ms, 미완주면 null

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.distanceKm,
    required this.status,
    this.finishedAtMs,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0.0,
        status: RunnerStatus.fromWire(j['status']?.toString()),
        finishedAtMs: (j['finishedAt'] as num?)?.toInt(),
      );
}

/// 경주 목표 — 목표거리(km)·제한시간(분).
class RaceGoal {
  final double targetDistance;
  final int limitMinutes;
  const RaceGoal({required this.targetDistance, required this.limitMinutes});

  factory RaceGoal.fromJson(Map<String, dynamic> j) => RaceGoal(
        targetDistance: (j['targetDistance'] as num?)?.toDouble() ?? 0.0,
        limitMinutes: (j['limitMinutes'] as num?)?.toInt() ?? 0,
      );
}

/// 리더보드 스냅샷 — 주기(~3초) 브로드캐스트 및 joinRoom ack 의 race 필드.
class LeaderboardSnapshot {
  final int roomId;
  final RaceStatus status;
  final int startedAtMs; // 출발 시각 epoch ms(서버 권위)
  final RaceGoal goal;
  final List<LeaderboardEntry> runners; // 거리 내림차순

  const LeaderboardSnapshot({
    required this.roomId,
    required this.status,
    required this.startedAtMs,
    required this.goal,
    required this.runners,
  });

  factory LeaderboardSnapshot.fromJson(Map<String, dynamic> j) {
    final rawRunners = (j['runners'] as List?) ?? const [];
    return LeaderboardSnapshot(
      roomId: (j['roomId'] as num?)?.toInt() ?? 0,
      status: RaceStatus.fromWire(j['status']?.toString()),
      startedAtMs: (j['startedAt'] as num?)?.toInt() ?? 0,
      goal: RaceGoal.fromJson(
          (j['goal'] as Map?)?.cast<String, dynamic>() ?? const {}),
      runners: [
        for (final r in rawRunners)
          if (r is Map)
            LeaderboardEntry.fromJson(r.cast<String, dynamic>()),
      ],
    );
  }

  /// 제한시간 종료 목표 epoch ms(= 출발 + 제한분). 남은시간 계산용.
  int get deadlineMs => startedAtMs + goal.limitMinutes * 60 * 1000;

  bool get isFinished => status == RaceStatus.finished;
}
