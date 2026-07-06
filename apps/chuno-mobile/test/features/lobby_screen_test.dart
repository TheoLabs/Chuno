// LobbyScreen 상세 실연동 — roomId 있으면 GET /rooms/:id 로 상세 로드/렌더.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/rooms/room_models.dart';
import 'package:chuno_mobile/features/rooms/room_providers.dart';
import 'package:chuno_mobile/features/rooms/room_repository.dart';
import 'package:chuno_mobile/models.dart' as mock;
import 'package:chuno_mobile/screens/lobby_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

class _DetailRepo implements RoomRepository {
  final bool fail;
  _DetailRepo({this.fail = false});
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
      maxParticipants: 5, scheduledStartOn: '2030-01-01 06:00:00', status: RoomStatus.recruiting,
      currentParticipantsCount: 3, isHost: true,
    );
  }
  @override
  Future<void> delete(int id) async {}
}

const _fallback = mock.Room(
  name: '폴백 방', targetKm: 5, limitMin: 40, cur: 1, max: 6,
  startInfo: '06:00 시작', status: mock.RoomStatus.soon,
);

Widget _app(RoomRepository repo) => ProviderScope(
      overrides: [roomRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const LobbyScreen(room: _fallback, roomId: 7),
      ),
    );

void main() {
  testWidgets('roomId 있으면 GET /rooms/:id 상세를 렌더한다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_DetailRepo()));
    await tester.pumpAndSettle();

    // 폴백이 아니라 서버 상세 필드가 표시돼야 한다.
    expect(find.text('서버가 준 방이름'), findsOneWidget);
    expect(find.text('목표 8km · 제한 55분'), findsOneWidget);
    expect(find.text('3/5명'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('상세 실패 시 재시도 배너를 렌더한다', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_DetailRepo(fail: true)));
    await tester.pumpAndSettle();

    expect(find.text('방 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
