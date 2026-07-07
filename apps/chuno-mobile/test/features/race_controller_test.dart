// 경주 소켓 이벤트 → 상태 매핑 + 오프라인 버퍼링/재동기 유닛테스트 (S3-7/8).
// 좌표는 서버 미전송 — reportProgress 는 거리(km)만 받는다.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/race/geo.dart';
import 'package:chuno_mobile/features/race/location_service.dart';
import 'package:chuno_mobile/features/race/race_controller.dart';
import 'package:chuno_mobile/features/race/race_models.dart';
import 'package:chuno_mobile/features/race/race_providers.dart';
import 'package:chuno_mobile/features/race/race_socket.dart';

class FakeRaceSocketChannel implements RaceSocketChannel {
  final _c = StreamController<RaceSocketMessage>.broadcast();
  final joinCalls = <int>[];
  final progressCalls = <double>[];
  final leaveCalls = <int>[];
  bool connectCalled = false;

  @override
  Stream<RaceSocketMessage> get messages => _c.stream;
  @override
  void connect() => connectCalled = true;
  @override
  void joinRoom(int roomId) => joinCalls.add(roomId);
  @override
  void reportProgress(int roomId, double distanceKm) =>
      progressCalls.add(distanceKm);
  @override
  void leaveRoom(int roomId) => leaveCalls.add(roomId);
  @override
  void dispose() => _c.close();

  void emit(RaceSocketMessage m) => _c.add(m);
}

class FakeLocationService implements LocationService {
  final _c = StreamController<GeoSample>.broadcast();
  @override
  Stream<GeoSample> positions() => _c.stream;
  @override
  Future<LocationAuth> currentAuth() async => LocationAuth.always;
  @override
  Future<LocationAuth> ensureAlwaysPermission() async => LocationAuth.always;
  @override
  Future<bool> openSettings() async => true;
  void push(GeoSample s) => _c.add(s);
}

GeoSample geo(double lat, {required int tMs}) => GeoSample(
      latitude: lat,
      longitude: 127.0,
      accuracy: 5,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: true),
    );

LeaderboardSnapshot snap({
  required String status,
  required List<Map<String, dynamic>> runners,
}) =>
    LeaderboardSnapshot.fromJson({
      'roomId': 1,
      'status': status,
      'startedAt': 1000,
      'goal': {'targetDistance': 5, 'limitMinutes': 40},
      'runners': runners,
    });

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeRaceSocketChannel channel;
  late FakeLocationService loc;
  late ProviderContainer container;
  const args = (roomId: 1, userId: 42);

  setUp(() {
    channel = FakeRaceSocketChannel();
    loc = FakeLocationService();
    container = ProviderContainer(overrides: [
      raceSocketChannelFactoryProvider.overrideWithValue((_) => channel),
      locationServiceProvider.overrideWithValue(loc),
    ]);
    // 리스너로 autoDispose 유지.
    container.listen(raceControllerProvider(args), (_, _) {},
        fireImmediately: true);
  });

  tearDown(() => container.dispose());

  RaceState read() => container.read(raceControllerProvider(args));

  test('build 시 소켓 connect 호출 + 초기 connecting', () {
    expect(channel.connectCalled, isTrue);
    expect(read().connection, RaceConnection.connecting);
  });

  test('연결 성립 → connected + joinRoom 재전송', () async {
    channel.emit(const RaceConnected());
    await settle();
    expect(read().connection, RaceConnection.connected);
    expect(channel.joinCalls, contains(1));
  });

  test('leaderboard 수신 → 스냅샷/서버시각 반영, 내 행 조회', () async {
    channel.emit(RaceLeaderboardMsg(
      snap(status: 'live', runners: [
        {'rank': 1, 'userId': 7, 'distanceKm': 3.0, 'status': 'running', 'finishedAt': null},
        {'rank': 2, 'userId': 42, 'distanceKm': 2.4, 'status': 'running', 'finishedAt': null},
      ]),
      serverTimeMs: DateTime.now().millisecondsSinceEpoch,
    ));
    await settle();
    final s = read();
    expect(s.snapshot!.runners.length, 2);
    expect(s.myEntry(42)!.distanceKm, 2.4);
    expect(s.myEntry(42)!.rank, 2);
  });

  test('finished 스냅샷/raceFinished → raceFinished 플래그', () async {
    channel.emit(const RaceFinishedMsg());
    await settle();
    expect(read().raceFinished, isTrue);
  });

  test('raceFinished 가 최종 leaderboard 보다 먼저 와도 RunnerFinished(내)로 완주 판정', () async {
    // 아직 내 상태는 running 인 스냅샷(주기 leaderboard 지연 상황).
    channel.emit(RaceLeaderboardMsg(snap(status: 'live', runners: [
      {'rank': 1, 'userId': 42, 'distanceKm': 5.0, 'status': 'running', 'finishedAt': null},
      {'rank': 2, 'userId': 7, 'distanceKm': 4.2, 'status': 'running', 'finishedAt': null},
    ])));
    await settle();
    // 내가 결승을 확정 → runnerFinished(내) 즉시 도착.
    channel.emit(const RunnerFinishedMsg(userId: 42, finishedAtMs: 123));
    // 최종 leaderboard(내 finished) 는 아직 안 왔는데 raceFinished 가 먼저 도착.
    channel.emit(const RaceFinishedMsg());
    await settle();

    final s = read();
    expect(s.raceFinished, isTrue);
    // 스냅샷상 내 상태는 여전히 running 이지만, myFinished 플래그로 완주 판정.
    expect(s.myEntry(42)!.status, RunnerStatus.running);
    expect(s.myFinished, isTrue);
    expect(s.isFinishedFor(42), isTrue); // ← DNF 오분류 방지(회귀)
  });

  test('타인 RunnerFinished 는 내 완주로 오인하지 않는다', () async {
    channel.emit(const RunnerFinishedMsg(userId: 7, finishedAtMs: 123));
    channel.emit(const RaceFinishedMsg());
    await settle();
    final s = read();
    expect(s.myFinished, isFalse);
    // 스냅샷 없음 + 로컬거리 0 → 미완주(DNF)로 판정.
    expect(s.isFinishedFor(42), isFalse);
  });

  test('위치 스트림 → 로컬 거리 누적 + 연결 시 거리만 보고', () async {
    channel.emit(const RaceConnected());
    await settle();
    channel.joinCalls.clear();
    channel.progressCalls.clear();

    loc.push(geo(37.5, tMs: 0)); // seed
    await settle();
    loc.push(geo(37.5010, tMs: 30000)); // ~111m 이동(30s, ≈13km/h)
    await settle();

    final s = read();
    expect(s.myDistanceKm, greaterThan(0.1));
    // 거리(double)만 전송 — 좌표 미포함.
    expect(channel.progressCalls, isNotEmpty);
    expect(channel.progressCalls.last, closeTo(s.myDistanceKm, 1e-9));
  });

  test('끊김 → 버퍼링, 로컬 거리 지속, 복귀 시 최신거리 재전송', () async {
    // 우선 연결/이동.
    channel.emit(const RaceConnected());
    await settle();
    loc.push(geo(37.5, tMs: 0));
    await settle();

    // 끊김.
    channel.emit(const RaceDisconnected());
    await settle();
    expect(read().connection, RaceConnection.disconnected);

    channel.progressCalls.clear();
    // 끊김 중 이동 — 로컬 누적은 되지만 서버 보고는 없음.
    loc.push(geo(37.5010, tMs: 30000));
    await settle();
    final offlineKm = read().myDistanceKm;
    expect(offlineKm, greaterThan(0.1));
    expect(read().buffering, isTrue);
    expect(channel.progressCalls, isEmpty); // 끊김 중 미전송

    // 복귀 → joinRoom + 최신 로컬거리 재전송.
    channel.emit(const RaceConnected());
    await settle();
    expect(read().buffering, isFalse);
    expect(channel.joinCalls, contains(1));
    expect(channel.progressCalls, isNotEmpty);
    expect(channel.progressCalls.last, closeTo(offlineKm, 1e-9));
  });

  test('저정확도 샘플 → GPS weak 표시', () async {
    loc.push(GeoSample(
        latitude: 37.5,
        longitude: 127.0,
        accuracy: 200,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
    await settle();
    expect(read().gps, GpsSignal.weak);
  });
}
