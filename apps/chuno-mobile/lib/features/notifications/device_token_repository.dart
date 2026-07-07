import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';

/// device-token 등록/해제 원격 계약 (S5-1 백엔드).
/// 인증 API 클라이언트(access 토큰 자동 첨부, UserGuard)를 쓴다.
abstract class DeviceTokenRepository {
  /// FCM 토큰 등록. `POST /users/me/device-tokens` body:{token, platform}.
  Future<void> register({required String token, required String platform});

  /// FCM 토큰 해제(로그아웃 시). `DELETE /users/me/device-tokens` body:{token}.
  Future<void> unregister(String token);
}

/// dio(ApiClient) 기반 구현.
class HttpDeviceTokenRepository implements DeviceTokenRepository {
  final ApiClient _client;
  HttpDeviceTokenRepository(this._client);

  Dio get _dio => _client.dio;

  @override
  Future<void> register({required String token, required String platform}) async {
    try {
      await _dio.post<dynamic>(
        ApiPaths.deviceTokens,
        data: {'token': token, 'platform': platform},
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<void> unregister(String token) async {
    try {
      await _dio.delete<dynamic>(
        ApiPaths.deviceTokens,
        data: {'token': token},
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
