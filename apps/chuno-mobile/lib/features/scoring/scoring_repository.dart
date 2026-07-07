import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import 'scoring_models.dart';

/// 스코어링(랭킹·결과·통계) 원격 호출 계약. 인증 API 클라이언트(access 토큰 자동 첨부)를 쓴다.
/// 응답 봉투 `{ data: ... }` 를 언랩한다.
abstract class ScoringRepository {
  /// 랭킹. `GET /rankings?scope=all|weekly|monthly` → `{ data: { items, total, me } }`.
  Future<RankingBoard> getRankings({required RankingScope scope});

  /// 내 기록 목록. `GET /users/me/results` (페이지네이션) → `{ data: { items, total } }`.
  Future<MyResultsPage> getMyResults({int? page, int? limit});

  /// 한 경주 전체 결과. `GET /races/:id/result` → `{ data: { raceId, results } }`(rank 오름차순).
  Future<RaceResultSet> getRaceResult(int raceId);
}

/// dio(ApiClient) 기반 구현. core-api scoring 계약을 따른다.
class HttpScoringRepository implements ScoringRepository {
  final ApiClient _client;
  HttpScoringRepository(this._client);

  Dio get _dio => _client.dio;

  static Map<String, dynamic> _unwrap(Object? data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  static List<RaceResultModel> _resultList(Object? raw) => [
        if (raw is List)
          for (final it in raw)
            if (it is Map) RaceResultModel.fromJson(Map<String, dynamic>.from(it)),
      ];

  @override
  Future<RankingBoard> getRankings({required RankingScope scope}) async {
    try {
      final res = await _dio.get<dynamic>(
        ApiPaths.rankings,
        queryParameters: {'scope': scope.wire},
      );
      final data = _unwrap(res.data);
      final rawItems = data['items'];
      final rawMe = data['me'];
      return RankingBoard(
        scope: scope,
        items: [
          if (rawItems is List)
            for (final it in rawItems)
              if (it is Map) RankingEntry.fromJson(Map<String, dynamic>.from(it)),
        ],
        total: (data['total'] as num?)?.toInt() ?? 0,
        me: rawMe is Map ? RankingEntry.fromJson(Map<String, dynamic>.from(rawMe)) : null,
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<MyResultsPage> getMyResults({int? page, int? limit}) async {
    try {
      final query = <String, dynamic>{'page': ?page, 'limit': ?limit};
      final res = await _dio.get<dynamic>(
        ApiPaths.myResults,
        queryParameters: query.isEmpty ? null : query,
      );
      final data = _unwrap(res.data);
      return MyResultsPage(
        items: _resultList(data['items']),
        total: (data['total'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<RaceResultSet> getRaceResult(int raceId) async {
    try {
      final res = await _dio.get<dynamic>(ApiPaths.raceResult(raceId));
      final data = _unwrap(res.data);
      return RaceResultSet(
        raceId: (data['raceId'] as num?)?.toInt() ?? raceId,
        results: _resultList(data['results']),
      );
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
