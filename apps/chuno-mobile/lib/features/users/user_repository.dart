import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import 'user_models.dart';

/// 사용자(users) 원격 호출 계약. 인증 API 클라이언트(access 토큰 자동 첨부)를 쓴다.
///
/// 응답 봉투 `{ data: ... }` 를 언랩해 도메인 값으로 반환한다.
abstract class UserRepository {
  /// 닉네임 사용 가능 여부. `GET /users/check-nickname?nickname=` → usedCount==0 이면 true.
  /// 길이/형식 위반 등은 [AppException] 으로 던진다.
  Future<bool> checkNickname(String nickname);

  /// 온보딩 저장. `PUT /users/onboard`. 성공 시 서버가 onboardedOn 을 설정한다.
  /// 닉네임 중복/필수 동의 누락 400, 이미 온보딩된 유저 409 등은 [AppException].
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  });

  /// 내 프로필 조회. `GET /users/me`. onboardedOn 포함(온보딩 판정용).
  Future<MeModel> getMe();
}

/// dio(ApiClient) 기반 구현. core-api 계약을 따른다.
class HttpUserRepository implements UserRepository {
  final ApiClient _client;
  HttpUserRepository(this._client);

  Dio get _dio => _client.dio;

  static Map<String, dynamic> _unwrap(Object? data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  @override
  Future<bool> checkNickname(String nickname) async {
    try {
      final res = await _dio.get<dynamic>(
        ApiPaths.checkNickname,
        queryParameters: {'nickname': nickname},
      );
      final data = _unwrap(res.data);
      final usedCount = (data['usedCount'] as num?)?.toInt() ?? 0;
      return usedCount == 0;
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<Consent> consents,
  }) async {
    try {
      await _dio.put<dynamic>(
        ApiPaths.onboard,
        data: {
          'nickname': nickname,
          'level': level,
          'consents': [for (final c in consents) c.toJson()],
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<MeModel> getMe() async {
    try {
      final res = await _dio.get<dynamic>(ApiPaths.me);
      return MeModel.fromJson(_unwrap(res.data));
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
