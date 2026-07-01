import 'package:dio/dio.dart';

import '../env/env.dart';
import '../storage/token_store.dart';
import 'auth_interceptor.dart';

/// baseUrl/타임아웃 등 공통 dio 옵션.
BaseOptions buildBaseOptions(Env env) => BaseOptions(
      baseUrl: env.baseUrl,
      connectTimeout: env.connectTimeout,
      receiveTimeout: env.receiveTimeout,
      contentType: 'application/json',
      headers: {'Accept': 'application/json'},
    );

/// 앱 공통 HTTP 클라이언트. dio 인스턴스에 인증 인터셉터를 조립한다.
///
/// refresh 호출은 인터셉터가 없는 별도 dio 로 수행해야 401→refresh→401 재귀가 없다.
/// 그 별도 dio 는 상위(provider)에서 주입한 [refresher] 안에 캡슐화된다.
class ApiClient {
  final Dio dio;
  ApiClient(this.dio);

  factory ApiClient.build({
    required Env env,
    required TokenStore tokenStore,
    required TokenRefresher refresher,
    void Function()? onSessionExpired,
  }) {
    final dio = Dio(buildBaseOptions(env));
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        refresher: refresher,
        retryDio: dio,
        onSessionExpired: onSessionExpired,
      ),
    );
    return ApiClient(dio);
  }
}
