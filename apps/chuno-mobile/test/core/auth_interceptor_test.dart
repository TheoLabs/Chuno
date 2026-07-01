// AuthInterceptor 검증:
//  - 401 → refresh 회전 → 원요청 재시도 성공
//  - 동시다발 401 에서 refresh single-flight(1회만 실행)
//  - refresh 실패 시 토큰 삭제 + 세션 만료 콜백 + 원 에러 전파
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/core/network/auth_interceptor.dart';
import 'package:chuno_mobile/core/network/tokens.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/core/storage/token_store.dart';

const _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Authorization 헤더에 따라 401/200 을 돌려주는 테스트용 어댑터.
class _FakeAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final auth = options.headers['Authorization'];
    // 짧은 비동기 지연으로 동시 요청이 겹치는 구간을 넓힌다.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (auth == 'Bearer new-access') {
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: _jsonHeaders,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'expired'}),
      401,
      headers: _jsonHeaders,
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _buildDio({
  required TokenStore tokenStore,
  required TokenRefresher refresher,
  required _FakeAdapter adapter,
  void Function()? onSessionExpired,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test.local'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(AuthInterceptor(
    tokenStore: tokenStore,
    refresher: refresher,
    retryDio: dio,
    onSessionExpired: onSessionExpired,
  ));
  return dio;
}

void main() {
  test('401 → refresh 회전 → 원요청 재시도 성공', () async {
    final store = TokenStore(InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'old-access',
      'chuno.auth.refreshToken': 'old-refresh',
    }));
    var refreshCalls = 0;
    final adapter = _FakeAdapter();
    final dio = _buildDio(
      tokenStore: store,
      adapter: adapter,
      refresher: (rt) async {
        refreshCalls++;
        expect(rt, 'old-refresh');
        return const TokenPair(accessToken: 'new-access', refreshToken: 'new-refresh');
      },
    );

    final res = await dio.get<Map<String, dynamic>>('/protected');

    expect(res.statusCode, 200);
    expect(res.data?['ok'], true);
    expect(refreshCalls, 1);
    // 회전형: 새 토큰이 저장되어야 한다.
    expect(await store.read(),
        const TokenPair(accessToken: 'new-access', refreshToken: 'new-refresh'));
    // 최초 401 + 재시도 200 = 2회.
    expect(adapter.calls, 2);
  });

  test('동시다발 401 에서 refresh 는 single-flight(1회만) 실행된다', () async {
    final store = TokenStore(InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'old-access',
      'chuno.auth.refreshToken': 'old-refresh',
    }));
    var refreshCalls = 0;
    final adapter = _FakeAdapter();
    final dio = _buildDio(
      tokenStore: store,
      adapter: adapter,
      refresher: (rt) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const TokenPair(accessToken: 'new-access', refreshToken: 'new-refresh');
      },
    );

    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/a'),
      dio.get<Map<String, dynamic>>('/b'),
      dio.get<Map<String, dynamic>>('/c'),
    ]);

    for (final r in results) {
      expect(r.statusCode, 200);
      expect(r.data?['ok'], true);
    }
    // 3개의 401 이 동시에 났지만 refresh 는 정확히 1회만.
    expect(refreshCalls, 1);
  });

  test('refresh 실패 시 토큰 삭제 + 세션 만료 콜백 + 원 에러 전파', () async {
    final store = TokenStore(InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'old-access',
      'chuno.auth.refreshToken': 'old-refresh',
    }));
    var expired = false;
    final adapter = _FakeAdapter();
    final dio = _buildDio(
      tokenStore: store,
      adapter: adapter,
      onSessionExpired: () => expired = true,
      refresher: (rt) async => throw StateError('refresh rejected'),
    );

    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>().having(
        (e) => e.response?.statusCode,
        'statusCode',
        401,
      )),
    );

    expect(expired, isTrue);
    expect(await store.read(), isNull);
    // 재시도되지 않았으므로 어댑터 호출은 최초 1회뿐.
    expect(adapter.calls, 1);
  });

  test('refresh 토큰이 없으면 즉시 세션 만료 처리', () async {
    final store = TokenStore(InMemoryKeyValueStore({
      'chuno.auth.accessToken': 'old-access',
      // refresh 토큰 없음
    }));
    var expired = false;
    final adapter = _FakeAdapter();
    final dio = _buildDio(
      tokenStore: store,
      adapter: adapter,
      onSessionExpired: () => expired = true,
      refresher: (rt) async =>
          const TokenPair(accessToken: 'new-access', refreshToken: 'new-refresh'),
    );

    await expectLater(dio.get<dynamic>('/protected'), throwsA(isA<DioException>()));
    expect(expired, isTrue);
    expect(await store.read(), isNull);
  });
}
