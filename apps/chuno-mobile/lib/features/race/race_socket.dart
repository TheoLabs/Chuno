import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'race_models.dart';

/// '/race' 소켓에서 흘러나오는 메시지(연결 상태 + 서버 브로드캐스트). 컨트롤러가 상태로 환원한다.
sealed class RaceSocketMessage {
  const RaceSocketMessage();
}

/// 연결 성립(최초/재접속). 컨트롤러는 이때 joinRoom 재전송 + 최신거리 재보고(오프라인 복귀 재동기).
class RaceConnected extends RaceSocketMessage {
  const RaceConnected();
}

/// 끊김 — socket.io 자동 재접속 진행. UI 는 연결끊김 배너, RunTracker 는 로컬 지속.
class RaceDisconnected extends RaceSocketMessage {
  const RaceDisconnected();
}

/// 연결 실패/거절(인증 실패 등).
class RaceConnectError extends RaceSocketMessage {
  final String? reason;
  const RaceConnectError([this.reason]);
}

/// 주기(~3초) 리더보드 브로드캐스트(`leaderboard`) 또는 joinRoom ack 의 race 스냅샷.
class RaceLeaderboardMsg extends RaceSocketMessage {
  final LeaderboardSnapshot snapshot;
  final int? serverTimeMs; // joinRoom ack 에만 실림(서버시각 동기용)
  const RaceLeaderboardMsg(this.snapshot, {this.serverTimeMs});
}

/// 한 러너 완주(`runnerFinished { userId, finishedAt }`).
class RunnerFinishedMsg extends RaceSocketMessage {
  final int? userId;
  final int? finishedAtMs;
  const RunnerFinishedMsg({this.userId, this.finishedAtMs});
}

/// 경주 종료(`raceFinished { roomId }`). UI 는 결과 화면으로 진입.
class RaceFinishedMsg extends RaceSocketMessage {
  const RaceFinishedMsg();
}

/// '/race' 소켓 채널 계약 — 실 socket.io 구현과 fake 테스트 더블을 분리한다.
abstract class RaceSocketChannel {
  Stream<RaceSocketMessage> get messages;

  /// 연결 시작(핸드셰이크 auth 포함). 재접속은 내부 자동.
  void connect();

  /// joinRoom — ack 로 서버시각·현재 리더보드를 받는다(RaceLeaderboardMsg 로 방출).
  void joinRoom(int roomId);

  /// 진행 거리 보고(RunTracker 누적거리). 좌표 미전송, 거리만.
  void reportProgress(int roomId, double distanceKm);

  /// 화면 이탈 정리(leaveRoom fire-and-forget).
  void leaveRoom(int roomId);

  void dispose();
}

/// socket.io 기반 실구현 — 네임스페이스 '/race', websocket, 핸드셰이크 `auth:{token}`.
/// 로비 소켓(IoRoomSocketChannel)과 동일 origin·인증 방식·재접속 백오프를 재사용한다.
class IoRaceSocketChannel implements RaceSocketChannel {
  /// 소켓 origin(예: `http://localhost:3000`) — '/race' 네임스페이스가 붙는다.
  final String url;

  /// 액세스 토큰 비동기 조회(재접속마다 재조회 → 회전 반영).
  final Future<String?> Function() tokenReader;

  final _controller = StreamController<RaceSocketMessage>.broadcast();
  io.Socket? _socket;
  bool _disposed = false;

  IoRaceSocketChannel({required this.url, required this.tokenReader});

  @override
  Stream<RaceSocketMessage> get messages => _controller.stream;

  @override
  void connect() {
    if (_socket != null || _disposed) return;
    final socket = io.io(
      '$url/race', // '/race' 네임스페이스
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setAuthFn((cb) {
            tokenReader().then((t) => cb({'token': t ?? ''}));
          })
          .build(),
    );

    socket.onConnect((_) => _add(const RaceConnected()));
    socket.onDisconnect((_) => _add(const RaceDisconnected()));
    socket.onConnectError((e) => _add(RaceConnectError(e?.toString())));
    socket.onError((e) => _add(RaceConnectError(e?.toString())));

    socket.on('leaderboard', (d) => _emitSnapshot(d));
    socket.on('runnerFinished', (d) => _add(RunnerFinishedMsg(
          userId: _int(d, 'userId'),
          finishedAtMs: _int(d, 'finishedAt'),
        )));
    socket.on('raceFinished', (_) => _add(const RaceFinishedMsg()));

    _socket = socket;
    socket.connect();
  }

  @override
  void joinRoom(int roomId) {
    final socket = _socket;
    if (socket == null) return;
    socket.emitWithAck('joinRoom', {'roomId': roomId},
        ack: (arg1, [dynamic arg2]) {
      final data = _dataMap(arg1);
      final race = data['race'];
      if (race is Map) {
        _add(RaceLeaderboardMsg(
          LeaderboardSnapshot.fromJson(race.cast<String, dynamic>()),
          serverTimeMs: (data['serverTime'] as num?)?.toInt(),
        ));
      }
    });
  }

  @override
  void reportProgress(int roomId, double distanceKm) {
    // fire-and-forget — 거리만 전송(좌표 미전송). ack(progressAck)는 표시 불필요라 무시.
    _socket?.emit('progress', {'roomId': roomId, 'distanceKm': distanceKm});
  }

  @override
  void leaveRoom(int roomId) {
    _socket?.emit('leaveRoom', {'roomId': roomId});
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _socket?.dispose();
    _socket = null;
    _controller.close();
  }

  void _emitSnapshot(dynamic payload) {
    if (payload is Map) {
      _add(RaceLeaderboardMsg(
          LeaderboardSnapshot.fromJson(payload.cast<String, dynamic>())));
    }
  }

  void _add(RaceSocketMessage m) {
    if (!_controller.isClosed) _controller.add(m);
  }

  static int? _int(dynamic payload, String key) {
    if (payload is Map && payload[key] is num) return (payload[key] as num).toInt();
    return null;
  }

  /// ack `{ event, data }` 에서 data Map 추출(로비 채널과 동일 규약).
  static Map<String, dynamic> _dataMap(dynamic ack) {
    if (ack is Map) {
      final data = ack['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return Map<String, dynamic>.from(ack);
    }
    return const {};
  }
}
