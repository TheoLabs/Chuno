// LobbySocketController — 소켓 메시지 → 로비 상태 환원(S2-8) 유닛테스트(fake 채널, 실서버 없음).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/rooms/lobby_socket_controller.dart';
import 'package:chuno_mobile/features/rooms/room_models.dart';
import 'package:chuno_mobile/features/rooms/room_providers.dart';
import 'package:chuno_mobile/features/rooms/room_repository.dart';
import 'package:chuno_mobile/features/rooms/room_socket.dart';

/// 메시지 스트림/ack 를 테스트가 제어하는 fake 소켓 채널.
class _FakeChannel implements RoomSocketChannel {
  final _c = StreamController<RoomSocketMessage>.broadcast();
  Map<String, dynamic> ackData;
  final List<String> emitted = [];
  bool connectCalled = false;
  bool disposed = false;

  _FakeChannel({this.ackData = const {'serverTime': 0}});

  void push(RoomSocketMessage m) => _c.add(m);

  @override
  Stream<RoomSocketMessage> get messages => _c.stream;
  @override
  void connect() => connectCalled = true;
  @override
  Future<Map<String, dynamic>> emitAck(String e, Map<String, dynamic> d) async {
    emitted.add(e);
    return ackData;
  }

  @override
  void emit(String e, Map<String, dynamic> d) => emitted.add(e);
  @override
  void dispose() {
    disposed = true;
    _c.close();
  }
}

/// retrieve 호출 횟수를 세는 방 저장소(참가/이탈 시 상세 리프레시 검증용).
class _CountingRoomRepo implements RoomRepository {
  int retrieveCalls = 0;
  @override
  Future<RoomModel> retrieve(int id) async {
    retrieveCalls++;
    return RoomModel(
      id: id, hostUserId: 'h1', name: '방', targetDistance: 5, limitMinutes: 40,
      maxParticipants: 6, scheduledStartOn: '2030-01-01 06:00:00',
      status: RoomStatus.recruiting, currentParticipantsCount: 3, isHost: false,
    );
  }

  @override
  Future<List<RoomModel>> list({
    List<RoomStatus>? statuses, int? minLimitMinutes, int? maxLimitMinutes,
    int? minTargetDistance, int? maxTargetDistance, int? page, int? limit,
    String? sort, String? order,
  }) async => const [];
  @override
  Future<int> create({
    required String name, required int targetDistance, required int limitMinutes,
    required int maxParticipants, required String scheduledStartOn,
  }) async => 1;
  @override
  Future<void> join(int id) async {}
  @override
  Future<void> delete(int id) async {}
  @override
  Future<void> leave(int id) async {}
}

/// 브로드캐스트 스트림 리스너/ack Future/invalidate 재계산을 흘려보낸다.
Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  ProviderContainer makeContainer(_FakeChannel channel, {RoomRepository? repo}) {
    final container = ProviderContainer(overrides: [
      roomSocketChannelFactoryProvider.overrideWithValue((_) => channel),
      if (repo != null) roomRepositoryProvider.overrideWithValue(repo),
    ]);
    // 리스너를 붙여 provider 를 살려두고 build(연결) 를 트리거한다.
    container.listen(lobbySocketProvider(7), (_, _) {});
    return container;
  }

  test('진입 시 connecting 상태 + connect() 호출', () {
    final channel = _FakeChannel();
    final container = makeContainer(channel);
    addTearDown(container.dispose);

    expect(container.read(lobbySocketProvider(7)).connection, LobbyConnection.connecting);
    expect(channel.connectCalled, isTrue);
  });

  test('SocketConnected → connected + joinRoom 재전송 + 서버시각 오프셋 동기', () async {
    final channel = _FakeChannel(ackData: const {'serverTime': 0});
    final container = makeContainer(channel);
    addTearDown(container.dispose);

    channel.push(const SocketConnected());
    await _flush();

    final s = container.read(lobbySocketProvider(7));
    expect(s.connection, LobbyConnection.connected);
    expect(channel.emitted, contains('joinRoom'));
    // serverTime=0(epoch) < 로컬 now → 오프셋은 큰 음수(동기됨).
    expect(s.clock.offsetMs, lessThan(0));
  });

  test('roomStatusChanged starting → status=starting + serverTime 재동기 emit', () async {
    final channel = _FakeChannel();
    final container = makeContainer(channel);
    addTearDown(container.dispose);

    channel.push(const RoomStatusChangedMsg('starting'));
    await _flush();

    expect(container.read(lobbySocketProvider(7)).status, RoomStatus.starting);
    expect(channel.emitted, contains('serverTime'));
  });

  test('roomStatusChanged live → status=live', () async {
    final channel = _FakeChannel();
    final container = makeContainer(channel);
    addTearDown(container.dispose);

    channel.push(const RoomStatusChangedMsg('live'));
    await _flush();

    expect(container.read(lobbySocketProvider(7)).status, RoomStatus.live);
  });

  test('roomCancelled → cancelled=true', () async {
    final channel = _FakeChannel();
    final container = makeContainer(channel);
    addTearDown(container.dispose);

    channel.push(const RoomCancelledMsg());
    await _flush();

    expect(container.read(lobbySocketProvider(7)).cancelled, isTrue);
  });

  test('SocketDisconnected → disconnected(재접속 대기)', () async {
    final channel = _FakeChannel();
    final container = makeContainer(channel);
    addTearDown(container.dispose);

    channel.push(const SocketDisconnected());
    await _flush();

    expect(container.read(lobbySocketProvider(7)).connection, LobbyConnection.disconnected);
  });

  test('participantJoined/Left → 상세(roomDetail) 재조회로 갱신', () async {
    final channel = _FakeChannel();
    final repo = _CountingRoomRepo();
    final container = makeContainer(channel, repo: repo);
    addTearDown(container.dispose);

    // roomDetail 을 살려둔다(초기 1회 조회).
    container.listen(roomDetailProvider(7), (_, _) {});
    await _flush();
    expect(repo.retrieveCalls, 1);

    channel.push(const ParticipantJoined('u2'));
    await _flush();
    expect(repo.retrieveCalls, 2);

    channel.push(const ParticipantLeft('u3'));
    await _flush();
    expect(repo.retrieveCalls, 3);
  });

  test('dispose 시 leaveRoom emit + 채널 정리', () async {
    final channel = _FakeChannel();
    final container = makeContainer(channel);

    container.dispose(); // autoDispose → onDispose 실행
    expect(channel.emitted, contains('leaveRoom'));
    expect(channel.disposed, isTrue);
  });
}
