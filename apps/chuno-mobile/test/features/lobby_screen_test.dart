// LobbyScreen 상세 실연동 — roomId 있으면 GET /rooms/:id 로 상세 로드/렌더.
// + 방장 방삭제(DELETE /rooms/:id)·참가자 나가기(DELETE /rooms/:id/leave) 실 API 배선.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/features/rooms/lobby_socket_controller.dart';
import 'package:chuno_mobile/features/rooms/room_models.dart';
import 'package:chuno_mobile/features/rooms/room_providers.dart';
import 'package:chuno_mobile/features/rooms/room_repository.dart';
import 'package:chuno_mobile/features/rooms/room_socket.dart';
import 'package:chuno_mobile/models.dart' as mock;
import 'package:chuno_mobile/screens/lobby_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

class _DetailRepo implements RoomRepository {
  final bool fail;
  final bool isHost;
  final RoomStatus status;
  final AppException? deleteError;
  final AppException? leaveError;
  int deleteCalls = 0;
  int leaveCalls = 0;
  _DetailRepo({
    this.fail = false,
    this.isHost = true,
    this.status = RoomStatus.recruiting,
    this.deleteError,
    this.leaveError,
  });
  @override
  Future<List<RoomModel>> list({
    List<RoomStatus>? statuses,
    int? minLimitMinutes,
    int? maxLimitMinutes,
    int? minTargetDistance,
    int? maxTargetDistance,
    int? page,
    int? limit,
    String? sort,
    String? order,
  }) async => const [];
  @override
  Future<int> create({
    required String name,
    required int targetDistance,
    required int limitMinutes,
    required int maxParticipants,
    required String scheduledStartOn,
  }) async => 1;
  @override
  Future<void> join(int id) async {}
  @override
  Future<RoomModel> retrieve(int id) async {
    if (fail) throw Exception('boom');
    return RoomModel(
      id: id, hostUserId: 'h1', name: '서버가 준 방이름', targetDistance: 8, limitMinutes: 55,
      maxParticipants: 5, scheduledStartOn: '2030-01-01 06:00:00', status: status,
      currentParticipantsCount: 3, isHost: isHost,
    );
  }
  @override
  Future<void> delete(int id) async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
  }
  @override
  Future<void> leave(int id) async {
    leaveCalls++;
    if (leaveError != null) throw leaveError!;
  }
}

const _fallback = mock.Room(
  name: '폴백 방', targetKm: 5, limitMin: 40, cur: 1, max: 6,
  startInfo: '06:00 시작', status: mock.RoomStatus.soon,
);

/// 실서버 없이 로비 렌더용 — 아무 이벤트도 흘리지 않는 조용한 소켓 채널.
class _SilentSocketChannel implements RoomSocketChannel {
  final _c = StreamController<RoomSocketMessage>.broadcast();
  @override
  Stream<RoomSocketMessage> get messages => _c.stream;
  @override
  void connect() {}
  @override
  Future<Map<String, dynamic>> emitAck(String e, Map<String, dynamic> d) async => const {};
  @override
  void emit(String e, Map<String, dynamic> d) {}
  @override
  void dispose() {
    _c.close();
  }
}

/// 테스트가 이벤트를 밀어넣을 수 있는 제어형 소켓 채널.
class _CtrlSocketChannel implements RoomSocketChannel {
  final _c = StreamController<RoomSocketMessage>.broadcast();
  void push(RoomSocketMessage m) => _c.add(m);
  @override
  Stream<RoomSocketMessage> get messages => _c.stream;
  @override
  void connect() {}
  @override
  Future<Map<String, dynamic>> emitAck(String e, Map<String, dynamic> d) async => const {'serverTime': 0};
  @override
  void emit(String e, Map<String, dynamic> d) {}
  @override
  void dispose() {
    _c.close();
  }
}

final _silentSocket = roomSocketChannelFactoryProvider.overrideWithValue((_) => _SilentSocketChannel());

/// 홈 → 로비 push 하니스에 제어형 채널을 주입한다.
Widget _pushAppWithChannel(RoomRepository repo, RoomSocketChannel channel) => ProviderScope(
      overrides: [
        roomRepositoryProvider.overrideWithValue(repo),
        roomSocketChannelFactoryProvider.overrideWithValue((_) => channel),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LobbyScreen(room: _fallback, roomId: 7),
                )),
                child: const Text('홈-마커'),
              ),
            ),
          ),
        ),
      ),
    );

Widget _app(RoomRepository repo) => ProviderScope(
      overrides: [roomRepositoryProvider.overrideWithValue(repo), _silentSocket],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const LobbyScreen(room: _fallback, roomId: 7),
      ),
    );

/// 홈 → 로비 push 하는 하니스(성공 시 홈 복귀 검증용).
Widget _pushApp(RoomRepository repo) => ProviderScope(
      overrides: [roomRepositoryProvider.overrideWithValue(repo), _silentSocket],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LobbyScreen(room: _fallback, roomId: 7),
                )),
                child: const Text('홈-마커'),
              ),
            ),
          ),
        ),
      ),
    );

void _sized(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('roomId 있으면 GET /rooms/:id 상세를 렌더한다', (tester) async {
    _sized(tester);
    await tester.pumpWidget(_app(_DetailRepo()));
    await tester.pumpAndSettle();

    expect(find.text('서버가 준 방이름'), findsOneWidget);
    expect(find.text('목표 8km · 제한 55분'), findsOneWidget);
    expect(find.text('3/5명'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('상세 실패 시 재시도 배너를 렌더한다', (tester) async {
    _sized(tester);
    await tester.pumpWidget(_app(_DetailRepo(fail: true)));
    await tester.pumpAndSettle();

    expect(find.text('방 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('방장·모집중이면 방 삭제 버튼만 노출한다', (tester) async {
    _sized(tester);
    await tester.pumpWidget(_app(_DetailRepo(isHost: true)));
    await tester.pumpAndSettle();

    expect(find.text('방 삭제'), findsOneWidget);
    expect(find.text('나가기'), findsNothing);
  });

  testWidgets('비방장·모집중이면 나가기 버튼만 노출한다', (tester) async {
    _sized(tester);
    await tester.pumpWidget(_app(_DetailRepo(isHost: false)));
    await tester.pumpAndSettle();

    expect(find.text('나가기'), findsOneWidget);
    expect(find.text('방 삭제'), findsNothing);
  });

  testWidgets('모집중이 아니면 삭제/나가기 버튼을 노출하지 않는다', (tester) async {
    _sized(tester);
    await tester.pumpWidget(_app(_DetailRepo(isHost: true, status: RoomStatus.live)));
    await tester.pumpAndSettle();

    expect(find.text('방 삭제'), findsNothing);
    expect(find.text('나가기'), findsNothing);
  });

  testWidgets('방 삭제 성공 → DELETE 호출·홈 복귀·성공 스낵바', (tester) async {
    _sized(tester);
    final repo = _DetailRepo(isHost: true);
    await tester.pumpWidget(_pushApp(repo));
    await tester.tap(find.text('홈-마커'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('방 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(find.text('홈-마커'), findsOneWidget); // 루트(홈)로 복귀
    expect(find.text('방이 삭제되었습니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('방 삭제 실패 → 백엔드 message 스낵바·로비 유지', (tester) async {
    _sized(tester);
    final repo = _DetailRepo(
      isHost: true,
      deleteError: const RequestFailure(message: '모집중인 방만 취소할 수 있습니다.', statusCode: 400),
    );
    await tester.pumpWidget(_pushApp(repo));
    await tester.tap(find.text('홈-마커'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('방 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(find.text('모집중인 방만 취소할 수 있습니다.'), findsOneWidget);
    expect(find.text('홈-마커'), findsNothing); // 아직 로비
    expect(tester.takeException(), isNull);
  });

  testWidgets('나가기 성공 → leave 호출·홈 복귀·성공 스낵바', (tester) async {
    _sized(tester);
    final repo = _DetailRepo(isHost: false);
    await tester.pumpWidget(_pushApp(repo));
    await tester.tap(find.text('홈-마커'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '나가기'));
    await tester.pumpAndSettle();

    expect(repo.leaveCalls, 1);
    expect(find.text('홈-마커'), findsOneWidget);
    expect(find.text('방에서 나갔습니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('나가기 실패 → 백엔드 message 스낵바·로비 유지', (tester) async {
    _sized(tester);
    final repo = _DetailRepo(
      isHost: false,
      leaveError: const RequestFailure(message: '방에 참여 중이지 않습니다.', statusCode: 400),
    );
    await tester.pumpWidget(_pushApp(repo));
    await tester.tap(find.text('홈-마커'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '나가기'));
    await tester.pumpAndSettle();

    expect(repo.leaveCalls, 1);
    expect(find.text('방에 참여 중이지 않습니다.'), findsOneWidget);
    expect(find.text('홈-마커'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roomCancelled 수신 → 안내 다이얼로그 → 확인 시 홈 복귀', (tester) async {
    _sized(tester);
    final channel = _CtrlSocketChannel();
    await tester.pumpWidget(_pushAppWithChannel(_DetailRepo(isHost: false), channel));
    await tester.tap(find.text('홈-마커'));
    await tester.pumpAndSettle();

    channel.push(const RoomCancelledMsg());
    await tester.pumpAndSettle();
    expect(find.text('방이 취소되었어요'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('홈-마커'), findsOneWidget); // 홈(루트)으로 복귀
    expect(find.text('방이 취소되었습니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('roomStatusChanged starting → 서버시계 카운트다운 화면으로 전환', (tester) async {
    _sized(tester);
    final channel = _CtrlSocketChannel();
    // scheduledStartOn=2030(먼 미래) → 카운트다운(대기) 상태로 진입.
    await tester.pumpWidget(_pushAppWithChannel(_DetailRepo(isHost: false), channel));
    await tester.tap(find.text('홈-마커'));
    await tester.pumpAndSettle();

    channel.push(const RoomStatusChangedMsg('starting'));
    await tester.pump(); // stream 이벤트 → controller 상태 변경
    await tester.pump(); // ref.listen 콜백 → Navigator.push
    await tester.pump(const Duration(milliseconds: 400)); // 라우트 전환 완료
    expect(find.text('동시 출발 대기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox()); // 카운트다운 타이머 정리
  });
}
