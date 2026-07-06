// HomeScreen 실연동 렌더 — 목록/빈 목록 분기.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/features/rooms/room_models.dart';
import 'package:chuno_mobile/features/rooms/room_providers.dart';
import 'package:chuno_mobile/features/rooms/room_repository.dart';
import 'package:chuno_mobile/screens/home_screen.dart';
import 'package:chuno_mobile/screens/lobby_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

class _ListRepo implements RoomRepository {
  /// 목록에 노출할 방(테스트마다 host/status 조정).
  final RoomModel room;

  /// join 이 던질 예외(null 이면 성공).
  final AppException? joinError;

  /// join 호출 여부/인자 기록.
  int joinCalls = 0;
  int? lastJoinedId;

  _ListRepo({RoomModel? room, this.joinError})
      : room = room ??
            const RoomModel(
              id: 1, hostUserId: 'h1', name: '5km 새벽 추격', targetDistance: 5, limitMinutes: 40,
              maxParticipants: 6, scheduledStartOn: '2030-01-01 06:00:00', status: RoomStatus.starting,
              currentParticipantsCount: 3, isHost: false,
            );

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
  }) async =>
      [room];
  @override
  Future<int> create({
    required String name,
    required int targetDistance,
    required int limitMinutes,
    required int maxParticipants,
    required String scheduledStartOn,
  }) async => 9;
  @override
  Future<void> join(int id) async {
    joinCalls++;
    lastJoinedId = id;
    if (joinError != null) throw joinError!;
  }
  @override
  Future<RoomModel> retrieve(int id) async => room;
  @override
  Future<void> delete(int id) async {}
}

class _EmptyRepo extends _ListRepo {
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
}

Widget _app(RoomRepository repo) => ProviderScope(
      overrides: [roomRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: SafeArea(child: HomeScreen())),
      ),
    );

void _setSmallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('목록이 있으면 방 카드를 렌더한다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_ListRepo()));
    await tester.pumpAndSettle();

    expect(find.text('5km 새벽 추격'), findsOneWidget);
    expect(find.text('곧 시작'), findsOneWidget); // starting 배지
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 목록이면 빈 상태를 렌더한다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_EmptyRepo()));
    await tester.pumpAndSettle();

    expect(find.text('열린 추격전이 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('참가 성공 → join 호출 후 로비로 진입한다', (tester) async {
    _setSmallScreen(tester);
    final repo = _ListRepo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('참가'));
    await tester.pumpAndSettle();

    expect(repo.joinCalls, 1);
    expect(repo.lastJoinedId, 1);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이미 참여 중이면 실패로 보지 않고 바로 로비로 진입한다', (tester) async {
    _setSmallScreen(tester);
    final repo = _ListRepo(
      joinError: const RequestFailure(message: '이미 참여 중인 방입니다.', statusCode: 400),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('참가'));
    await tester.pumpAndSettle();

    expect(repo.joinCalls, 1);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(find.text('이미 참여 중인 방입니다.'), findsNothing); // 스낵바 미노출
    expect(tester.takeException(), isNull);
  });

  testWidgets('정원초과 등 실패는 로비 진입 없이 안내 스낵바를 띄운다', (tester) async {
    _setSmallScreen(tester);
    final repo = _ListRepo(
      joinError: const RequestFailure(message: '방 정원이 가득 찼습니다.', statusCode: 400),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('참가'));
    await tester.pump(); // 로딩 닫고 스낵바 표시
    await tester.pump();

    expect(repo.joinCalls, 1);
    expect(find.byType(LobbyScreen), findsNothing);
    expect(find.text('방 정원이 가득 찼습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('방장 자기 방은 join 없이 바로 로비로 진입한다', (tester) async {
    _setSmallScreen(tester);
    final repo = _ListRepo(
      room: const RoomModel(
        id: 7, hostUserId: 'me', name: '내가 만든 방', targetDistance: 5, limitMinutes: 40,
        maxParticipants: 6, scheduledStartOn: '2030-01-01 06:00:00', status: RoomStatus.recruiting,
        currentParticipantsCount: 1, isHost: true,
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('참가'));
    await tester.pumpAndSettle();

    expect(repo.joinCalls, 0);
    expect(find.byType(LobbyScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
