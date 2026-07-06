// HttpRoomRepository 계약 검증 — list(?statuses,min/max,sort)·create(data.room.id) 경로·언랩.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/core/env/env.dart';
import 'package:chuno_mobile/core/network/api_client.dart';
import 'package:chuno_mobile/features/rooms/room_models.dart';
import 'package:chuno_mobile/features/rooms/room_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HttpRoomRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    repo = HttpRoomRepository(ApiClient(dio));
  });

  test('list → GET /rooms, statuses 콤마조인·min/max·sort/order 쿼리, data.items 언랩', () async {
    adapter.onGet(
      ApiPaths.rooms,
      (server) => server.reply(200, {
        'data': {
          'items': [
            {
              'id': 1,
              'hostUserId': 'h1',
              'name': '5km 새벽 추격',
              'targetDistance': 5,
              'limitMinutes': 40,
              'maxParticipants': 6,
              'scheduledStartOn': '2030-01-01 06:00:00',
              'status': 'starting',
              'currentParticipantsCount': 3,
              'isHost': false,
            },
          ],
          'total': 1,
        }
      }),
      queryParameters: {
        'statuses': 'recruiting,starting,live',
        'maxTargetDistance': 5,
        'minLimitMinutes': 31,
        'sort': 'scheduledStartOn',
        'order': 'ASC',
      },
    );

    final rooms = await repo.list(
      statuses: const [RoomStatus.recruiting, RoomStatus.starting, RoomStatus.live],
      maxTargetDistance: 5,
      minLimitMinutes: 31,
      sort: 'scheduledStartOn',
      order: 'ASC',
    );
    expect(rooms.length, 1);
    expect(rooms.first.id, 1);
    expect(rooms.first.name, '5km 새벽 추격');
    expect(rooms.first.targetDistance, 5);
    expect(rooms.first.status, RoomStatus.starting);
    expect(rooms.first.remainingSlots, 3);
  });

  test('list → 빈 목록이면 빈 리스트', () async {
    adapter.onGet(
      ApiPaths.rooms,
      (server) => server.reply(200, {
        'data': {'items': [], 'total': 0}
      }),
      queryParameters: {'sort': 'scheduledStartOn', 'order': 'ASC'},
    );
    final rooms = await repo.list(sort: 'scheduledStartOn', order: 'ASC');
    expect(rooms, isEmpty);
  });

  test('create → POST /rooms, data.room.id 반환', () async {
    final body = {
      'name': '5km 새벽 추격',
      'targetDistance': 5,
      'limitMinutes': 40,
      'maxParticipants': 6,
      'scheduledStartOn': '2030-01-01 06:00:00',
    };
    adapter.onPost(
      ApiPaths.rooms,
      (server) => server.reply(201, {
        'data': {
          'room': {'id': 42}
        }
      }),
      data: body,
    );

    final id = await repo.create(
      name: '5km 새벽 추격',
      targetDistance: 5,
      limitMinutes: 40,
      maxParticipants: 6,
      scheduledStartOn: '2030-01-01 06:00:00',
    );
    expect(id, 42);
  });

  test('retrieve → GET /rooms/:id, data 언랩(단건)', () async {
    adapter.onGet(
      '${ApiPaths.rooms}/7',
      (server) => server.reply(200, {
        'data': {
          'id': 7,
          'hostUserId': 'h9',
          'name': '3km 스프린트',
          'targetDistance': 3,
          'limitMinutes': 20,
          'maxParticipants': 4,
          'scheduledStartOn': '2030-01-01 07:00:00',
          'status': 'recruiting',
          'currentParticipantsCount': 2,
          'isHost': true,
        }
      }),
    );
    final room = await repo.retrieve(7);
    expect(room.id, 7);
    expect(room.name, '3km 스프린트');
    expect(room.isHost, isTrue);
    expect(room.remainingSlots, 2);
  });

  test('create → 400(도메인 가드 위반)은 AppException(RequestFailure)', () async {
    adapter.onPost(
      ApiPaths.rooms,
      (server) => server.reply(400, {'message': '최대 인원은 2명 이상이어야 합니다.'}),
      data: Matchers.any,
    );
    expect(
      () => repo.create(
        name: 'x',
        targetDistance: 5,
        limitMinutes: 40,
        maxParticipants: 1,
        scheduledStartOn: '2030-01-01 06:00:00',
      ),
      throwsA(isA<RequestFailure>()),
    );
  });
}
