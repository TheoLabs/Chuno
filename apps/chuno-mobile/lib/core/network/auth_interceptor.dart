// private 필드는 named 초기화 형식 인자로 쓸 수 없어 초기화 목록으로 대입한다.
// ignore_for_file: prefer_initializing_formals
import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'tokens.dart';

/// refresh 토큰으로 새 토큰 쌍을 발급받는 함수 계약.
/// 실패 시 예외를 던지고, 성공 시 회전된 새 [TokenPair] 를 반환한다.
typedef TokenRefresher = Future<TokenPair> Function(String refreshToken);

/// 401 응답 시 refresh 토큰으로 토큰을 회전(rotating refresh)하고 원요청을 재시도하는 인터셉터.
///
/// - onRequest: 저장된 access 토큰을 Authorization 헤더에 부착.
/// - onError(401): refresh → 저장 → 원요청 재시도. refresh 실패 시 토큰 삭제 + 세션 만료 콜백.
/// - single-flight: 동시다발 401 이 와도 refresh 는 1회만 실행되고 나머지는 그 결과를 대기한다.
class AuthInterceptor extends Interceptor {
  /// 재시도 무한루프 방지 플래그(요청 extra 키).
  static const _retriedKey = 'chuno.auth.retried';

  /// 이 요청에는 access 토큰 부착/refresh 처리를 하지 않는다(예: refresh 요청 자체).
  static const skipAuthKey = 'chuno.auth.skip';

  final TokenStore _tokenStore;
  final TokenRefresher _refresher;

  /// 원요청 재시도에 사용할 dio. (보통 이 인터셉터가 붙은 dio 와 동일)
  final Dio _retryDio;

  /// refresh 최종 실패(=재로그인 필요) 시 호출. 세션 컨트롤러가 로그아웃 처리를 건다.
  final void Function()? onSessionExpired;

  AuthInterceptor({
    required TokenStore tokenStore,
    required TokenRefresher refresher,
    required Dio retryDio,
    this.onSessionExpired,
  })  : _tokenStore = tokenStore,
        _refresher = refresher,
        _retryDio = retryDio;

  /// single-flight 를 위한 진행 중 refresh future.
  Future<TokenPair?>? _inflight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final access = await _tokenStore.readAccessToken();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    final skip = options.extra[skipAuthKey] == true;
    final alreadyRetried = options.extra[_retriedKey] == true;

    if (!is401 || skip || alreadyRetried) {
      return handler.next(err);
    }

    final refreshed = await _refresh();
    if (refreshed == null) {
      // refresh 실패 → 원 에러를 그대로 전파(토큰은 _refresh 내부에서 정리됨).
      return handler.next(err);
    }

    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      final response = await _retryDio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// single-flight refresh. 진행 중이면 같은 future 를 재사용한다.
  Future<TokenPair?> _refresh() {
    final existing = _inflight;
    if (existing != null) return existing;

    final future = _runRefresh();
    _inflight = future;
    future.whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    });
    return future;
  }

  Future<TokenPair?> _runRefresh() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStore.clear();
      onSessionExpired?.call();
      return null;
    }
    try {
      final pair = await _refresher(refreshToken);
      await _tokenStore.save(pair); // 회전형: 새 access+refresh 저장
      return pair;
    } catch (_) {
      await _tokenStore.clear();
      onSessionExpired?.call();
      return null;
    }
  }
}
