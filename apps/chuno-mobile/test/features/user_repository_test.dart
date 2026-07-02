// HttpUserRepository 계약 검증 — check-nickname / onboard / me 경로·바디·응답 언랩.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/core/env/env.dart';
import 'package:chuno_mobile/core/network/api_client.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HttpUserRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    repo = HttpUserRepository(ApiClient(dio));
  });

  test('checkNickname → GET /users/check-nickname, usedCount==0 이면 available=true', () async {
    adapter.onGet(
      ApiPaths.checkNickname,
      (server) => server.reply(200, {
        'data': {'usedCount': 0}
      }),
      queryParameters: {'nickname': '러너'},
    );
    expect(await repo.checkNickname('러너'), isTrue);
  });

  test('checkNickname → usedCount>0 이면 available=false', () async {
    adapter.onGet(
      ApiPaths.checkNickname,
      (server) => server.reply(200, {
        'data': {'usedCount': 3}
      }),
      queryParameters: {'nickname': '중복'},
    );
    expect(await repo.checkNickname('중복'), isFalse);
  });

  test('checkNickname → 400(길이 위반)은 AppException(RequestFailure)', () async {
    adapter.onGet(
      ApiPaths.checkNickname,
      (server) => server.reply(400, {'message': '닉네임 길이 오류'}),
      queryParameters: {'nickname': 'x'},
    );
    expect(
      () => repo.checkNickname('x'),
      throwsA(isA<RequestFailure>()),
    );
  });

  test('onboard → PUT /users/onboard, body {nickname, level, consents}', () async {
    final body = {
      'nickname': '러너_추노',
      'level': 'intermediate',
      'consents': [
        {'type': 'terms', 'documentVersion': '1.0'},
        {'type': 'privacy', 'documentVersion': '1.0'},
        {'type': 'location', 'documentVersion': '1.0'},
      ],
    };
    adapter.onPut(
      ApiPaths.onboard,
      (server) => server.reply(200, {'data': {}}),
      data: body,
    );

    await expectLater(
      repo.onboard(
        nickname: '러너_추노',
        level: RunnerLevel.intermediate.wire,
        consents: const [
          Consent(type: 'terms', documentVersion: '1.0'),
          Consent(type: 'privacy', documentVersion: '1.0'),
          Consent(type: 'location', documentVersion: '1.0'),
        ],
      ),
      completes,
    );
  });

  test('onboard → 409(이미 온보딩)은 AppException(RequestFailure)', () async {
    adapter.onPut(
      ApiPaths.onboard,
      (server) => server.reply(409, {'message': '이미 온보딩됨'}),
      data: Matchers.any,
    );
    expect(
      () => repo.onboard(
        nickname: '러너',
        level: 'beginner',
        consents: const [Consent(type: 'terms', documentVersion: '1.0')],
      ),
      throwsA(isA<RequestFailure>()),
    );
  });

  test('getMe → GET /users/me, onboardedOn 있으면 isOnboarded=true', () async {
    adapter.onGet(
      ApiPaths.me,
      (server) => server.reply(200, {
        'data': {
          'id': 'u1',
          'nickname': '러너_추노',
          'level': 'intermediate',
          'tier': 'bronze',
          'onboardedOn': '2026-07-01T00:00:00.000Z',
        }
      }),
    );
    final me = await repo.getMe();
    expect(me.id, 'u1');
    expect(me.nickname, '러너_추노');
    expect(me.isOnboarded, isTrue);
  });

  test('getMe → onboardedOn null 이면 isOnboarded=false', () async {
    adapter.onGet(
      ApiPaths.me,
      (server) => server.reply(200, {
        'data': {'id': 'u1', 'onboardedOn': null}
      }),
    );
    final me = await repo.getMe();
    expect(me.isOnboarded, isFalse);
  });
}
