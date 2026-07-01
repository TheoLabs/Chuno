import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/tokens.dart';

/// 인증 관련 원격 호출 계약. 백엔드(S1-5) 확정 전 인터페이스만 고정한다.
abstract class AuthRepository {
  /// refresh 토큰으로 새 토큰 쌍을 회전 발급한다. 실패 시 [AppException].
  Future<TokenPair> refresh(String refreshToken);

  /// 소셜 로그인 등으로 얻은 자격으로 세션 토큰을 발급한다.(S1-8 이후 실제 연동)
  Future<TokenPair> login({
    required String provider,
    required String credential,
  });

  /// 서버 세션 무효화.(best-effort)
  Future<void> logout(String refreshToken);
}

/// dio 기반 구현. 실 서버/스키마는 미확정이므로 경로/파싱은 placeholder 계약을 따른다.
class HttpAuthRepository implements AuthRepository {
  /// 인증 인터셉터가 붙지 않은 dio(=refreshDio). refresh 재귀를 피하기 위함.
  final Dio _dio;
  HttpAuthRepository(this._dio);

  static Options get _skipAuth =>
      Options(extra: {AuthInterceptor.skipAuthKey: true});

  static TokenPair _parseTokens(Object? data) {
    final map = data is Map && data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : Map<String, dynamic>.from(data as Map);
    return TokenPair.fromJson(map);
  }

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<dynamic>(
        ApiPaths.refresh,
        data: {'refreshToken': refreshToken},
        options: _skipAuth,
      );
      return _parseTokens(res.data);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<TokenPair> login({
    required String provider,
    required String credential,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        ApiPaths.login,
        data: {'provider': provider, 'credential': credential},
        options: _skipAuth,
      );
      return _parseTokens(res.data);
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<dynamic>(
        ApiPaths.logout,
        data: {'refreshToken': refreshToken},
        options: _skipAuth,
      );
    } on DioException {
      // best-effort: 로컬 토큰 삭제는 세션 컨트롤러가 담당.
    }
  }
}
