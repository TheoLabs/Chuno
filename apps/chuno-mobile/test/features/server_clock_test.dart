// ServerClock — 서버시각 오프셋 보정 카운트다운 로직(S2-9) 유닛테스트.
import 'package:flutter_test/flutter_test.dart';
import 'package:chuno_mobile/features/rooms/server_clock.dart';

void main() {
  group('ServerClock.fromServerTime', () {
    test('로컬이 서버보다 3초 느리면 offset 은 +3000ms', () {
      final local = DateTime.fromMillisecondsSinceEpoch(1_000_000);
      final clock = ServerClock.fromServerTime(1_003_000, localAt: local);
      expect(clock.offsetMs, 3000);
    });

    test('로컬이 서버보다 빠르면 offset 은 음수', () {
      final local = DateTime.fromMillisecondsSinceEpoch(2_000_000);
      final clock = ServerClock.fromServerTime(1_998_500, localAt: local);
      expect(clock.offsetMs, -1500);
    });
  });

  group('remaining 계산 (remaining = target − (localNow + offset))', () {
    // 로컬이 서버보다 5초 느린 상황: offset = +5000.
    const clock = ServerClock(5000);
    final local = DateTime.fromMillisecondsSinceEpoch(100_000);

    test('nowMs = localNow + offset', () {
      expect(clock.nowMs(local), 105_000);
    });

    test('target 이 서버now 로부터 10초 뒤면 remainingMs = 10000', () {
      expect(clock.remainingMs(115_000, local), 10_000);
    });

    test('이미 지난 target 이면 remainingMs 음수', () {
      expect(clock.remainingMs(104_000, local), -1000);
    });
  });

  group('remainingSeconds (올림·0 하한)', () {
    const clock = ServerClock.unsynced; // offset 0
    final local = DateTime.fromMillisecondsSinceEpoch(0);

    test('9500ms 남으면 10초로 올림', () {
      expect(clock.remainingSeconds(9500, local), 10);
    });

    test('정확히 10000ms 남으면 10초', () {
      expect(clock.remainingSeconds(10_000, local), 10);
    });

    test('1ms 남아도 1초', () {
      expect(clock.remainingSeconds(1, local), 1);
    });

    test('0 이하는 0초', () {
      expect(clock.remainingSeconds(0, local), 0);
      expect(clock.remainingSeconds(-2000, local), 0);
    });
  });

  test('서로 다른 오프셋의 두 기기가 같은 target 에서 같은 남은시간을 본다(동시출발)', () {
    // 기기 A: 로컬이 서버보다 4초 빠름(offset -4000).
    // 기기 B: 로컬이 서버보다 7초 느림(offset +7000).
    // 각자 자신의 로컬시각으로 계산해도 서버 기준 remaining 은 동일해야 한다.
    const target = 1_000_000;
    final serverNow = DateTime.fromMillisecondsSinceEpoch(990_000); // 서버 기준 10초 전

    final aLocal = DateTime.fromMillisecondsSinceEpoch(
        serverNow.millisecondsSinceEpoch + 4000); // A 로컬이 4s 빠름
    final clockA = const ServerClock(-4000);

    final bLocal = DateTime.fromMillisecondsSinceEpoch(
        serverNow.millisecondsSinceEpoch - 7000); // B 로컬이 7s 느림
    final clockB = const ServerClock(7000);

    expect(clockA.remainingMs(target, aLocal), 10_000);
    expect(clockB.remainingMs(target, bLocal), 10_000);
  });
}
