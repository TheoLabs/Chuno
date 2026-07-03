import 'package:dio/dio.dart';

import '../../core/env/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import 'legal_models.dart';

/// 법적 문서(legal-documents) 원격 호출 계약. 응답 봉투 `{ data: ... }` 를 언랩한다.
abstract class LegalDocumentRepository {
  /// 활성 문서 목록. `GET /legal-documents?types=<slug>,<slug>` →
  /// `{ data: { items: [...], total } }`. list 응답엔 content 가 없다.
  Future<List<LegalDocument>> list({required List<String> types});

  /// 단건 조회(전문 포함). `GET /legal-documents/:id` →
  /// `{ data: { ..., content, expectedActivateOn } }`.
  Future<LegalDocument> retrieve(int id);
}

/// dio(ApiClient) 기반 구현. core-api 계약을 따른다.
class HttpLegalDocumentRepository implements LegalDocumentRepository {
  final ApiClient _client;
  HttpLegalDocumentRepository(this._client);

  Dio get _dio => _client.dio;

  static Map<String, dynamic> _unwrap(Object? data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  @override
  Future<List<LegalDocument>> list({required List<String> types}) async {
    try {
      final res = await _dio.get<dynamic>(
        ApiPaths.legalDocuments,
        queryParameters: {'types': types.join(',')},
      );
      final data = _unwrap(res.data);
      final items = data['items'];
      if (items is! List) return const [];
      return [
        for (final it in items)
          if (it is Map)
            LegalDocument.fromJson(Map<String, dynamic>.from(it)),
      ];
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }

  @override
  Future<LegalDocument> retrieve(int id) async {
    try {
      final res = await _dio.get<dynamic>('${ApiPaths.legalDocuments}/$id');
      return LegalDocument.fromJson(_unwrap(res.data));
    } on DioException catch (e) {
      throw AppException.fromDio(e);
    }
  }
}
