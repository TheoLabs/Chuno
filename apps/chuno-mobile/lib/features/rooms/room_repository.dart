import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import 'room_models.dart';

/// 방(rooms) 원격 호출 계약. 인증 API 클라이언트(access 토큰 자동 첨부)를 쓴다.
/// 응답 봉투 `{ data: ... }` 를 언랩한다. 배열 쿼리는 콤마 조인(프로젝트 공통 규약).
abstract class RoomRepository {
  /// 방 목록. `GET /rooms` → `{ data: { items: [...], total } }`.
  /// 필터/정렬은 모두 선택. [statuses] 는 콤마 조인. 임박순 = sort=scheduledStartOn&order=ASC.
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
  });

  /// 방 생성. `POST /rooms` → `{ data: { room: { id } } }`. 생성된 방 id(정수) 를 반환한다.
  Future<int> create({
    required String name,
    required int targetDistance,
    required int limitMinutes,
    required int maxParticipants,
    required String scheduledStartOn,
  });

  /// 방 참가. `POST /rooms/:id/join` → 성공 `{ data: {} }`.
  /// 실패는 전부 400(RequestFailure)로, 사유가 `message` 에 담긴다:
  /// 모집중 아님/중복(이미 참여 중)/정원초과/미존재. 호출부에서 message 로 분기한다.
  Future<void> join(int id);

  /// 방 단건 조회. `GET /rooms/:id` → `{ data: {...} }`. 로비 상세에서 사용.
  Future<RoomModel> retrieve(int id);

  /// 방 취소(방장). `DELETE /rooms/:id`. (배선 선택)
  Future<void> delete(int id);
}

/// dio(ApiClient) 기반 구현. core-api 계약을 따른다.
class HttpRoomRepository implements RoomRepository {
  final ApiClient _client;
  HttpRoomRepository(this._client);

  Dio get _dio => _client.dio;

  static Map<String, dynamic> _unwrap(Object? data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

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
  }) async {
    try {
      final query = <String, dynamic>{
        if (statuses != null && statuses.isNotEmpty)
          'statuses': statuses.map((s) => s.wire).join(','),
        'minLimitMinutes': ?minLimitMinutes,
        'maxLimitMinutes': ?maxLimitMinutes,
        'minTargetDistance': ?minTargetDistance,
        'maxTargetDistance': ?maxTargetDistance,
        'page': ?page,
        'limit': ?limit,
        'sort': ?sort,
        'order': ?order,
      };
      final res = await _dio.get<dynamic>(
        ApiPaths.rooms,
        queryParameters: query.isEmpty ? null : query,
      );
      final data = _unwrap(res.data);
      final items = data['items'];
      if (items is! List) return const [];
      return [
        for (final it in items)
          if (it is Map) RoomModel.fromJson(Map<String, dynamic>.from(it)),
      ];
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<int> create({
    required String name,
    required int targetDistance,
    required int limitMinutes,
    required int maxParticipants,
    required String scheduledStartOn,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        ApiPaths.rooms,
        data: {
          'name': name,
          'targetDistance': targetDistance,
          'limitMinutes': limitMinutes,
          'maxParticipants': maxParticipants,
          'scheduledStartOn': scheduledStartOn,
        },
      );
      final data = _unwrap(res.data);
      final room = data['room'];
      final id = room is Map ? room['id'] : null;
      return (id as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<void> join(int id) async {
    try {
      await _dio.post<dynamic>('${ApiPaths.rooms}/$id/join');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<RoomModel> retrieve(int id) async {
    try {
      final res = await _dio.get<dynamic>('${ApiPaths.rooms}/$id');
      return RoomModel.fromJson(_unwrap(res.data));
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<void> delete(int id) async {
    try {
      await _dio.delete<dynamic>('${ApiPaths.rooms}/$id');
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
