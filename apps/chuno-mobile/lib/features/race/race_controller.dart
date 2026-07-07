import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rooms/server_clock.dart';
import 'geo.dart';
import 'race_models.dart';
import 'race_providers.dart';
import 'race_socket.dart';
import 'run_tracker.dart';

/// 경주 소켓 연결 상태.
enum RaceConnection { connecting, connected, disconnected }

/// GPS 신호 상태(S3-9 안내용).
enum GpsSignal {
  none, // 아직 위치 미확보
  weak, // 저정확도 샘플만 들어옴
  ok, // 정상 측정 중
}

/// 경주 화면 상태(S3-7/8/9). 서버 리더보드(권위) + 로컬 RunTracker(내 거리) 결합.
class RaceState {
  final RaceConnection connection;
  final ServerClock clock;

  /// 최신 서버 리더보드 스냅샷. null=아직 미수신(joinRoom 전).
  final LeaderboardSnapshot? snapshot;

  /// 로컬 RunTracker 누적 거리(km) — 연결끊김 중에도 내 행은 이 값으로 계속 표시.
  final double myDistanceKm;

  final GpsSignal gps;

  /// 연결끊김으로 서버 미반영 상태(로컬 거리 버퍼링 중).
  final bool buffering;

  /// raceFinished 수신(경주 종료). UI 는 결과 화면 진입.
  final bool raceFinished;

  /// 내가 완주했음(`runnerFinished{userId==나}` 이벤트로 확정). 3초 주기 leaderboard 보다
  /// 즉시 오는 raceFinished 와의 경쟁조건에서, 최종 스냅샷이 늦어도 완주로 판정하기 위한 플래그.
  final bool myFinished;

  const RaceState({
    this.connection = RaceConnection.connecting,
    this.clock = ServerClock.unsynced,
    this.snapshot,
    this.myDistanceKm = 0.0,
    this.gps = GpsSignal.none,
    this.buffering = false,
    this.raceFinished = false,
    this.myFinished = false,
  });

  RaceState copyWith({
    RaceConnection? connection,
    ServerClock? clock,
    LeaderboardSnapshot? snapshot,
    double? myDistanceKm,
    GpsSignal? gps,
    bool? buffering,
    bool? raceFinished,
    bool? myFinished,
  }) =>
      RaceState(
        connection: connection ?? this.connection,
        clock: clock ?? this.clock,
        snapshot: snapshot ?? this.snapshot,
        myDistanceKm: myDistanceKm ?? this.myDistanceKm,
        gps: gps ?? this.gps,
        buffering: buffering ?? this.buffering,
        raceFinished: raceFinished ?? this.raceFinished,
        myFinished: myFinished ?? this.myFinished,
      );

  /// 내 리더보드 행(서버 스냅샷 기준). 없으면 null.
  LeaderboardEntry? myEntry(int userId) {
    final runners = snapshot?.runners;
    if (runners == null) return null;
    for (final r in runners) {
      if (r.userId == userId) return r;
    }
    return null;
  }

  /// 완주 여부(경쟁조건 안전) — 다음 중 하나라도 참이면 완주로 본다:
  /// (1) 최종 스냅샷의 내 상태 finished, (2) runnerFinished(내) 플래그,
  /// (3) 로컬 누적거리가 목표거리 도달. 셋 다 아니면 미완주(DNF).
  bool isFinishedFor(int userId, {double? goalKm}) {
    if (myEntry(userId)?.status == RunnerStatus.finished) return true;
    if (myFinished) return true;
    final goal = goalKm ?? snapshot?.goal.targetDistance;
    if (goal != null && goal > 0 && myDistanceKm >= goal - 1e-6) return true;
    return false;
  }

  bool get disconnected => connection == RaceConnection.disconnected;
}

/// 경주 컨트롤러 인자(방·나) — family 키.
typedef RaceArgs = ({int roomId, int userId});

/// 경주 실시간 컨트롤러(S3-7/8/9). 화면 진입 시 watch → 소켓 연결·joinRoom + 위치 스트림 구독.
/// 이탈(autoDispose) 시 leaveRoom·정리. 소켓/위치 소스는 provider 로 주입해 fake 테스트 가능.
class RaceController extends AutoDisposeFamilyNotifier<RaceState, RaceArgs> {
  RaceSocketChannel? _channel;
  StreamSubscription<RaceSocketMessage>? _socketSub;
  StreamSubscription<GeoSample>? _geoSub;
  RunTracker? _tracker;

  /// 마지막으로 서버에 보고한 거리(중복 보고 억제). 연결끊김 복귀 시 재전송 기준.
  double _lastReportedKm = -1;

  @override
  RaceState build(RaceArgs arg) {
    final tracker = RunTracker();
    _tracker = tracker;

    final channel = ref.watch(raceSocketChannelFactoryProvider)(arg.roomId);
    _channel = channel;
    _socketSub = channel.messages.listen(_onSocket);

    final location = ref.watch(locationServiceProvider);
    _geoSub = location.positions().listen(_onGeo, onError: (_) {});

    ref.onDispose(() {
      try {
        channel.leaveRoom(arg.roomId);
      } catch (_) {}
      _socketSub?.cancel();
      _geoSub?.cancel();
      channel.dispose();
    });

    channel.connect();
    return const RaceState();
  }

  // ── 위치 스트림 → RunTracker(로컬 거리) ──────────────────────────────
  void _onGeo(GeoSample s) {
    final tracker = _tracker;
    if (tracker == null) return;
    final outcome = tracker.add(s);
    final gps = switch (outcome) {
      RunSampleOutcome.lowAccuracy => GpsSignal.weak,
      _ => GpsSignal.ok,
    };
    state = state.copyWith(myDistanceKm: tracker.distanceKm, gps: gps);
    _reportIfConnected();
  }

  /// 연결돼 있고 거리가 늘었으면 서버로 보고(좌표 미전송, 거리만). 끊김이면 버퍼링 표시.
  void _reportIfConnected() {
    final channel = _channel;
    if (channel == null) return;
    final km = state.myDistanceKm;
    if (state.connection == RaceConnection.connected) {
      if (km > _lastReportedKm) {
        channel.reportProgress(arg.roomId, km);
        _lastReportedKm = km;
      }
    } else {
      // 끊김 중 — 로컬로 계속 측정하되 서버 미반영(복귀 시 재전송).
      if (!state.buffering) state = state.copyWith(buffering: true);
    }
  }

  // ── 소켓 이벤트 → 상태 ───────────────────────────────────────────────
  void _onSocket(RaceSocketMessage m) {
    switch (m) {
      case RaceConnected():
        state = state.copyWith(
            connection: RaceConnection.connected, buffering: false);
        _channel?.joinRoom(arg.roomId);
        _resendLatest(); // 오프라인 복귀 재동기 — 최신 로컬거리 즉시 재전송.
      case RaceDisconnected():
      case RaceConnectError():
        state = state.copyWith(connection: RaceConnection.disconnected);
      case RaceLeaderboardMsg(:final snapshot, :final serverTimeMs):
        var next = state.copyWith(snapshot: snapshot);
        if (serverTimeMs != null) {
          next = next.copyWith(clock: ServerClock.fromServerTime(serverTimeMs));
        }
        if (snapshot.isFinished) next = next.copyWith(raceFinished: true);
        state = next;
      case RunnerFinishedMsg(:final userId):
        // 개별 완주 알림 — 내 완주면 즉시 플래그 세팅(3초 주기 leaderboard 를 기다리지 않고
        // raceFinished 와의 경쟁조건에서도 완주로 판정되게). 타인 완주는 다음 주기 리더보드로 반영.
        if (userId != null && userId == arg.userId) {
          state = state.copyWith(myFinished: true);
        }
      case RaceFinishedMsg():
        state = state.copyWith(raceFinished: true);
    }
  }

  /// 연결 복귀 시 최신 로컬거리를 서버로 재전송(재동기). 버퍼링 해제.
  void _resendLatest() {
    final channel = _channel;
    if (channel == null) return;
    final km = state.myDistanceKm;
    channel.reportProgress(arg.roomId, km);
    _lastReportedKm = km;
  }

  /// 중도 포기(DNF) — 화면에서 확인 후 호출. 서버 권위 상태는 제한시간/전원완주로 확정되므로
  /// 여기서는 로컬 정리만 하고(leaveRoom) 화면이 결과로 이동한다.
  void quit() {
    try {
      _channel?.leaveRoom(arg.roomId);
    } catch (_) {}
  }
}

/// 경주 컨트롤러 provider(방·나 키). autoDispose — 화면 이탈 시 정리.
final raceControllerProvider =
    NotifierProvider.autoDispose.family<RaceController, RaceState, RaceArgs>(
  RaceController.new,
);
