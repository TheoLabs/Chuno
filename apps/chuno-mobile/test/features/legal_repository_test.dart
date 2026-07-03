// HttpLegalDocumentRepository 계약 검증 — list(?types=)/retrieve(:id) 경로·언랩.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:chuno_mobile/core/error/app_exception.dart';
import 'package:chuno_mobile/core/env/env.dart';
import 'package:chuno_mobile/core/network/api_client.dart';
import 'package:chuno_mobile/features/legal/legal_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HttpLegalDocumentRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    repo = HttpLegalDocumentRepository(ApiClient(dio));
  });

  test('list → GET /legal-documents?types=, data.items 언랩(콘텐츠 없음)', () async {
    adapter.onGet(
      ApiPaths.legalDocuments,
      (server) => server.reply(200, {
        'data': {
          'items': [
            {'id': 1, 'type': 'terms-of-service', 'version': 'v1.0', 'title': '이용약관', 'isRequired': true, 'status': 'ACTIVE'},
            {'id': 4, 'type': 'marketing', 'version': 'v1.0', 'title': '마케팅 수신', 'isRequired': false, 'status': 'ACTIVE'},
          ],
          'total': 2,
        }
      }),
      queryParameters: {'types': 'terms-of-service,marketing'},
    );

    final docs = await repo.list(types: ['terms-of-service', 'marketing']);
    expect(docs.length, 2);
    expect(docs.first.id, 1);
    expect(docs.first.type, 'terms-of-service');
    expect(docs.first.isRequired, isTrue);
    expect(docs.first.content, isNull); // list 응답엔 content 없음
    expect(docs[1].isRequired, isFalse);
  });

  test('retrieve → GET /legal-documents/:id, content·expectedActivateOn 포함', () async {
    adapter.onGet(
      '${ApiPaths.legalDocuments}/1',
      (server) => server.reply(200, {
        'data': {
          'id': 1,
          'type': 'terms-of-service',
          'version': 'v1.0',
          'title': '이용약관',
          'isRequired': true,
          'status': 'ACTIVE',
          'content': '제1조 (목적) ...',
          'expectedActivateOn': '2026-01-01',
        }
      }),
    );

    final doc = await repo.retrieve(1);
    expect(doc.id, 1);
    expect(doc.content, '제1조 (목적) ...');
    expect(doc.expectedActivateOn, '2026-01-01');
  });

  test('retrieve → 500 은 AppException(ServerFailure)', () async {
    adapter.onGet(
      '${ApiPaths.legalDocuments}/9',
      (server) => server.reply(500, {'message': '서버 오류'}),
    );
    expect(() => repo.retrieve(9), throwsA(isA<ServerFailure>()));
  });
}
