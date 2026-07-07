/// 서버시각 오프셋 보정 시계 — S2-9 동시출발 카운트다운의 핵심 로직.
///
/// 클라 로컬시계는 기기마다 어긋날 수 있으므로, 서버가 준 시각(joinRoom ack /
/// serverTime ack 의 epoch ms)으로 오프셋을 구해 보정한다.
///
///   offset    = serverTime − localNow   (동기 시점 1회 계산)
///   serverNow = localNow + offset
///   remaining = target − serverNow
///
/// 순수 계산만 담아 실서버 없이 유닛테스트한다.
class ServerClock {
  /// serverTime − localNow (ms). 로컬이 서버보다 빠르면 음수.
  final int offsetMs;

  const ServerClock(this.offsetMs);

  /// 미동기(오프셋 0) 기본값 — 로컬시계를 그대로 서버시계로 본다.
  static const ServerClock unsynced = ServerClock(0);

  /// joinRoom/serverTime ack 로 오프셋을 계산해 시계를 만든다.
  /// [serverTimeMs] = 서버가 준 epoch ms, [localAt] = 그 응답을 받은 로컬 시각.
  factory ServerClock.fromServerTime(int serverTimeMs, {DateTime? localAt}) {
    final local = (localAt ?? DateTime.now()).millisecondsSinceEpoch;
    return ServerClock(serverTimeMs - local);
  }

  /// 서버 기준 현재 epoch ms.
  int nowMs([DateTime? local]) =>
      (local ?? DateTime.now()).millisecondsSinceEpoch + offsetMs;

  /// [targetEpochMs] 까지 서버 기준 남은 ms. 이미 지났으면 음수.
  int remainingMs(int targetEpochMs, [DateTime? local]) =>
      targetEpochMs - nowMs(local);

  /// 카운트다운 표시용 남은 '초'(올림, 0 하한). 남은 900ms → 1, 0 이하 → 0.
  int remainingSeconds(int targetEpochMs, [DateTime? local]) {
    final ms = remainingMs(targetEpochMs, local);
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }
}
