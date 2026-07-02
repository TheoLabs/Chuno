// HttpAuthRepository 계약 검증 — core-api(social-login) 경로/바디/응답 파싱.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:chuno_mobile/core/env/env.dart';
import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/features/auth/auth_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HttpAuthRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    repo = HttpAuthRepository(dio);
  });

  test('login → POST /auth/social-login, body {provider, token}, 평면 토큰 파싱', () async {
    adapter.onPost(
      ApiPaths.socialLogin,
      (server) => server.reply(200, {
        'accessToken': 'ac',
        'refreshToken': 'rf',
      }),
      data: {'provider': 'kakao', 'token': 'dev:dev-kakao:dev+kakao@chuno.local'},
    );

    final tokens = await repo.login(
      provider: 'kakao',
      credential: 'dev:dev-kakao:dev+kakao@chuno.local',
    );

    expect(tokens, const TokenPair(accessToken: 'ac', refreshToken: 'rf'));
  });

  test('refresh → POST /auth/refresh, 평면 토큰 파싱', () async {
    adapter.onPost(
      ApiPaths.refresh,
      (server) => server.reply(200, {
        'accessToken': 'ac2',
        'refreshToken': 'rf2',
      }),
      data: {'refreshToken': 'old-rf'},
    );

    final tokens = await repo.refresh('old-rf');
    expect(tokens, const TokenPair(accessToken: 'ac2', refreshToken: 'rf2'));
  });
}
