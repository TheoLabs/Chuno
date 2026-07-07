import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// 로비 소켓에서 흘러나오는 메시지(연결 상태 + 서버 브로드캐스트 이벤트).
/// 컨트롤러가 이 스트림을 구독해 상태로 환원한다.
sealed class RoomSocketMessage {
  const RoomSocketMessage();
}

/// 소켓 연결 성립(최초 연결/재접속 모두). 컨트롤러는 이때 joinRoom 을 재전송해
/// 자격을 재검증하고 오프셋을 재동기한다.
class SocketConnected extends RoomSocketMessage {
  const SocketConnected();
}

/// 소켓 끊김(네트워크/서버). socket.io 가 자동 재접속을 시도한다.
class SocketDisconnected extends RoomSocketMessage {
  const SocketDisconnected();
}

/// 연결 자체가 거절/실패(인증 실패 등). 메시지는 표시용.
class SocketConnectError extends RoomSocketMessage {
  final String? reason;
  const SocketConnectError([this.reason]);
}

/// 타인이 방에 참가함(`participantJoined { userId }`).
class ParticipantJoined extends RoomSocketMessage {
  final String? userId;
  const ParticipantJoined([this.userId]);
}

/// 타인이 방에서 이탈함(`participantLeft { userId }`).
class ParticipantLeft extends RoomSocketMessage {
  final String? userId;
  const ParticipantLeft([this.userId]);
}

/// 방 상태 전환(`roomStatusChanged { status: 'starting' | 'live' }`).
class RoomStatusChangedMsg extends RoomSocketMessage {
  final String status;
  const RoomStatusChangedMsg(this.status);
}

/// 방 취소(`roomCancelled {}`).
class RoomCancelledMsg extends RoomSocketMessage {
  const RoomCancelledMsg();
}

/// 로비 소켓 채널 계약 — 실제 socket.io 구현과 fake 테스트 더블을 분리한다.
/// 컨트롤러는 이 인터페이스에만 의존하므로 실서버 없이 유닛테스트가 가능하다.
abstract class RoomSocketChannel {
  /// 연결 상태 변화 + 서버 이벤트 스트림.
  Stream<RoomSocketMessage> get messages;

  /// 연결 시작(핸드셰이크 auth 포함). 재접속은 내부적으로 자동 처리된다.
  void connect();

  /// ack 를 기다리는 emit. 서버 ack `{ event, data }` 의 `data` Map 을 반환한다.
  Future<Map<String, dynamic>> emitAck(String event, Map<String, dynamic> data);

  /// ack 없이 fire-and-forget emit(화면 이탈 정리용 leaveRoom 등).
  void emit(String event, Map<String, dynamic> data);

  /// 정리(구독 해제 + 소켓 파기).
  void dispose();
}

/// socket.io 기반 실제 구현. 기본 네임스페이스('/'), websocket 전송,
/// 핸드셰이크 `auth: { token }`(secure storage 액세스 토큰). 재접속은 지수 백오프.
class IoRoomSocketChannel implements RoomSocketChannel {
  /// 소켓 서버 origin(예: `http://localhost:3000`). dio baseUrl 과 동일 호스트, 포트 3000.
  final String url;

  /// 액세스 토큰 비동기 조회(재접속마다 재조회 → 회전된 토큰 반영).
  final Future<String?> Function() tokenReader;

  final _controller = StreamController<RoomSocketMessage>.broadcast();
  io.Socket? _socket;
  bool _disposed = false;

  IoRoomSocketChannel({required this.url, required this.tokenReader});

  @override
  Stream<RoomSocketMessage> get messages => _controller.stream;

  @override
  void connect() {
    if (_socket != null || _disposed) return;
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000) // 백오프 시작 1s
          .setReconnectionDelayMax(8000) // 상한 8s
          // 매 (재)연결 시 토큰을 비동기로 재조회해 auth 에 실어 보낸다.
          .setAuthFn((cb) {
            tokenReader().then((t) => cb({'token': t ?? ''}));
          })
          .build(),
    );

    socket.onConnect((_) => _add(const SocketConnected()));
    socket.onDisconnect((_) => _add(const SocketDisconnected()));
    socket.onConnectError((e) => _add(SocketConnectError(e?.toString())));
    socket.onError((e) => _add(SocketConnectError(e?.toString())));

    socket.on('participantJoined',
        (d) => _add(ParticipantJoined(_str(d, 'userId'))));
    socket.on('participantLeft',
        (d) => _add(ParticipantLeft(_str(d, 'userId'))));
    socket.on('roomStatusChanged', (d) {
      final s = _str(d, 'status');
      if (s != null) _add(RoomStatusChangedMsg(s));
    });
    socket.on('roomCancelled', (_) => _add(const RoomCancelledMsg()));

    _socket = socket;
    socket.connect();
  }

  @override
  Future<Map<String, dynamic>> emitAck(
      String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null) {
      return Future.error(StateError('socket not connected'));
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(event, data, ack: (arg1, [dynamic arg2]) {
      if (completer.isCompleted) return;
      completer.complete(_dataMap(arg1));
    });
    return completer.future.timeout(const Duration(seconds: 5));
  }

  @override
  void emit(String event, Map<String, dynamic> data) {
    _socket?.emit(event, data);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _socket?.dispose();
    _socket = null;
    _controller.close();
  }

  void _add(RoomSocketMessage m) {
    if (!_controller.isClosed) _controller.add(m);
  }

  /// 이벤트 payload(첫 인자)에서 문자열 필드 추출. Map 이 아니면 null.
  static String? _str(dynamic payload, String key) {
    if (payload is Map && payload[key] != null) return payload[key].toString();
    return null;
  }

  /// ack payload `{ event, data }` 에서 `data` Map 을 꺼낸다.
  static Map<String, dynamic> _dataMap(dynamic ack) {
    if (ack is Map) {
      final data = ack['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return Map<String, dynamic>.from(ack);
    }
    return const {};
  }
}
