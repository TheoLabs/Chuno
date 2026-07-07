// HttpScoringRepository 계약 검증 — rankings / me results / race result 경로·쿼리·응답 매핑.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:chuno_mobile/core/env/env.dart';
import 'package:chuno_mobile/core/network/api_client.dart';
import 'package:chuno_mobile/features/scoring/scoring_models.dart';
import 'package:chuno_mobile/features/scoring/scoring_repository.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late HttpScoringRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;
    repo = HttpScoringRepository(ApiClient(dio));
  });

  test('getRankings → GET /rankings?scope=weekly, items/total/me 매핑', () async {
    adapter.onGet(
      ApiPaths.rankings,
      (server) => server.reply(200, {
        'data': {
          'items': [
            {'rank': 1, 'userId': 10, 'score': 21050},
            {'rank': 2, 'userId': 42, 'score': 19900},
          ],
          'total': 128,
          'me': {'rank': 2, 'userId': 42, 'score': 19900},
        }
      }),
      queryParameters: {'scope': 'weekly'},
    );

    final board = await repo.getRankings(scope: RankingScope.weekly);
    expect(board.scope, RankingScope.weekly);
    expect(board.total, 128);
    expect(board.items.length, 2);
    expect(board.items.first.userId, 10);
    expect(board.me?.rank, 2);
    expect(board.me?.userId, 42);
  });

  test('getRankings → me == null(참가 이력 없음)', () async {
    adapter.onGet(
      ApiPaths.rankings,
      (server) => server.reply(200, {
        'data': {'items': [], 'total': 0, 'me': null}
      }),
      queryParameters: {'scope': 'all'},
    );
    final board = await repo.getRankings(scope: RankingScope.all);
    expect(board.me, isNull);
    expect(board.items, isEmpty);
  });

  test('getMyResults → GET /users/me/results?limit=, 4축 점수 평탄 매핑', () async {
    adapter.onGet(
      ApiPaths.myResults,
      (server) => server.reply(200, {
        'data': {
          'items': [
            {
              'id': 5, 'raceId': 3, 'userId': 42, 'finished': true, 'distanceKm': 5.0,
              'finishTime': 722.0, 'rank': 1, 'total': 820, 'rankScore': 300,
              'distanceScore': 200, 'finishBonus': 220, 'marginScore': 100, 'pointsAwarded': 82,
            },
          ],
          'total': 1,
        }
      }),
      queryParameters: {'limit': 100},
    );

    final page = await repo.getMyResults(limit: 100);
    expect(page.total, 1);
    final r = page.items.single;
    expect(r.raceId, 3);
    expect(r.finished, isTrue);
    expect(r.finishTime, 722.0);
    expect(r.rankScore, 300);
    expect(r.marginScore, 100);
    expect(r.pointsAwarded, 82);
  });

  test('getRaceResult → GET /races/:id/result, results/rank 오름차순 매핑 + DNF finishTime null', () async {
    adapter.onGet(
      ApiPaths.raceResult(7),
      (server) => server.reply(200, {
        'data': {
          'raceId': 7,
          'results': [
            {
              'id': 1, 'raceId': 7, 'userId': 42, 'finished': true, 'distanceKm': 5.0,
              'finishTime': 700.0, 'rank': 1, 'total': 800, 'rankScore': 300,
              'distanceScore': 200, 'finishBonus': 220, 'marginScore': 80, 'pointsAwarded': 80,
            },
            {
              'id': 2, 'raceId': 7, 'userId': 99, 'finished': false, 'distanceKm': 4.1,
              'finishTime': null, 'rank': 2, 'total': 210, 'rankScore': 0,
              'distanceScore': 164, 'finishBonus': 0, 'marginScore': 46, 'pointsAwarded': 21,
            },
          ],
        }
      }),
    );

    final set = await repo.getRaceResult(7);
    expect(set.raceId, 7);
    expect(set.results.length, 2);
    expect(set.forUser(42)?.rank, 1);
    expect(set.forUser(99)?.finished, isFalse);
    expect(set.forUser(99)?.finishTime, isNull);
    expect(set.podium.map((r) => r.rank), [1, 2]);
  });
}
