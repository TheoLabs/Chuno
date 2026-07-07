import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'room_models.dart';
import 'room_providers.dart';
import 'room_socket.dart';
import 'server_clock.dart';

/// 로비 소켓 연결 상태.
enum LobbyConnection {
  connecting, // 최초 연결 시도 중
  connected, // 연결됨(joinRoom 성공 여부와 별개)
  disconnected, // 끊김 — socket.io 가 백오프 재접속 시도 중
}

/// 로비 소켓의 UI 상태 스냅샷. 카운트다운 계산에 쓰는 [clock]과
/// 서버가 통보한 [status] 오버라이드, 취소/연결 상태를 담는다.
class LobbySocketState {
  final LobbyConnection connection;

  /// 서버시각 오프셋 보정 시계(joinRoom/serverTime ack 로 갱신).
  final ServerClock clock;

  /// 서버가 통보한 방 상태(roomStatusChanged). null 이면 REST 상세 status 를 따른다.
  final RoomStatus? status;

  /// 방 취소(roomCancelled) 수신 여부 — UI 는 안내 후 홈 복귀.
  final bool cancelled;

  const LobbySocketState({
    this.connection = LobbyConnection.connecting,
    this.clock = ServerClock.unsynced,
    this.status,
    this.cancelled = false,
  });

  LobbySocketState copyWith({
    LobbyConnection? connection,
    ServerClock? clock,
    RoomStatus? status,
    bool? cancelled,
  }) =>
      LobbySocketState(
        connection: connection ?? this.connection,
        clock: clock ?? this.clock,
        status: status ?? this.status,
        cancelled: cancelled ?? this.cancelled,
      );
}

/// roomId 로 소켓 채널을 만드는 팩토리. 테스트에서 fake 로 override 한다.
typedef RoomSocketChannelFactory = RoomSocketChannel Function(int roomId);

/// 기본 팩토리 — socket.io(IoRoomSocketChannel). dio baseUrl 과 동일 호스트,
/// 포트 3000, 기본 네임스페이스. 액세스 토큰은 secure storage 에서 (재)조회한다.
final roomSocketChannelFactoryProvider =
    Provider<RoomSocketChannelFactory>((ref) {
  final env = ref.watch(envProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final origin = _socketOrigin(env.baseUrl);
  return (roomId) => IoRoomSocketChannel(
        url: origin,
        tokenReader: tokenStore.readAccessToken,
      );
});

/// dio baseUrl(`http://host:3000/api`) 에서 소켓 origin(`http://host:3000`) 추출.
String _socketOrigin(String baseUrl) {
  try {
    final u = Uri.parse(baseUrl);
    if (u.hasScheme && u.host.isNotEmpty) return u.origin;
  } catch (_) {}
  return baseUrl;
}

/// 로비 실시간 소켓 컨트롤러(방별). 로비 진입 시 watch → 연결·joinRoom,
/// 화면 이탈(autoDispose) 시 leaveRoom·정리. 재접속 시 joinRoom 재전송으로 자격 재검증.
final lobbySocketProvider = NotifierProvider.autoDispose
    .family<LobbySocketController, LobbySocketState, int>(
  LobbySocketController.new,
);

class LobbySocketController
    extends AutoDisposeFamilyNotifier<LobbySocketState, int> {
  RoomSocketChannel? _channel;
  StreamSubscription<RoomSocketMessage>? _sub;

  @override
  LobbySocketState build(int arg) {
    final channel = ref.watch(roomSocketChannelFactoryProvider)(arg);
    _channel = channel;
    _sub = channel.messages.listen(_onMessage);
    ref.onDispose(() {
      // 화면 이탈 정리 — leaveRoom 은 best-effort(도메인상 방 나가기는 REST DELETE).
      try {
        channel.emit('leaveRoom', {'roomId': arg});
      } catch (_) {}
      _sub?.cancel();
      channel.dispose();
    });
    channel.connect();
    return const LobbySocketState();
  }

  void _onMessage(RoomSocketMessage m) {
    switch (m) {
      case SocketConnected():
        state = state.copyWith(connection: LobbyConnection.connected);
        _joinAndSync();
      case SocketDisconnected():
      case SocketConnectError():
        state = state.copyWith(connection: LobbyConnection.disconnected);
      case ParticipantJoined():
      case ParticipantLeft():
        // 명단 API 부재 → 상세를 리프레시해 인원/그리드를 갱신한다.
        ref.invalidate(roomDetailProvider(arg));
      case RoomStatusChangedMsg(:final status):
        final next = RoomStatus.fromWire(status);
        state = state.copyWith(status: next);
        // 카운트다운 진입 직전 오프셋을 한 번 더 조인다(정확도).
        if (next == RoomStatus.starting) _resync();
      case RoomCancelledMsg():
        state = state.copyWith(cancelled: true);
        ref.invalidate(roomDetailProvider(arg));
    }
  }

  /// joinRoom emit → ack.serverTime 으로 오프셋 동기.
  Future<void> _joinAndSync() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      final data = await channel.emitAck('joinRoom', {'roomId': arg});
      _applyServerTime(data['serverTime']);
    } catch (_) {
      // 조인 실패(비참가자/타임아웃) — 오프셋 미동기(로컬시계 사용). 연결은 유지.
    }
  }

  /// serverTime emit → 오프셋 재동기(재접속·카운트다운 직전 등).
  Future<void> _resync() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      final data = await channel.emitAck('serverTime', const {});
      _applyServerTime(data['serverTime']);
    } catch (_) {}
  }

  void _applyServerTime(Object? serverTime) {
    final ms = serverTime is num
        ? serverTime.toInt()
        : int.tryParse(serverTime?.toString() ?? '');
    if (ms == null) return;
    state = state.copyWith(clock: ServerClock.fromServerTime(ms));
  }
}
