// 스코어링 provider/집계 로직 검증 — 결과 뷰(raceId 유무별) + 통계 요약.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/scoring/scoring_models.dart';
import 'package:chuno_mobile/features/scoring/scoring_providers.dart';
import 'package:chuno_mobile/features/scoring/scoring_repository.dart';

RaceResultModel _result({
  required int raceId,
  required int userId,
  required int rank,
  bool finished = true,
  double distanceKm = 5.0,
  int total = 800,
}) =>
    RaceResultModel(
      id: rank, raceId: raceId, userId: userId, finished: finished, distanceKm: distanceKm,
      finishTime: finished ? 700.0 : null, rank: rank, total: total, rankScore: 300,
      distanceScore: 200, finishBonus: finished ? 220 : 0, marginScore: 80, pointsAwarded: 80,
    );

/// 호출 횟수를 세는 fake — 폴백 폴링/직접 조회 경로 분기 검증용.
class _FakeScoringRepository implements ScoringRepository {
  final MyResultsPage myResults;
  final RaceResultSet raceResult;
  int myResultsCalls = 0;
  int raceResultCalls = 0;

  _FakeScoringRepository({required this.myResults, required this.raceResult});

  @override
  Future<RankingBoard> getRankings({required RankingScope scope}) async =>
      RankingBoard(scope: scope, items: const [], total: 0);

  @override
  Future<MyResultsPage> getMyResults({int? page, int? limit}) async {
    myResultsCalls++;
    return myResults;
  }

  @override
  Future<RaceResultSet> getRaceResult(int raceId) async {
    raceResultCalls++;
    return raceResult;
  }
}

ProviderContainer _container(ScoringRepository repo) {
  final c = ProviderContainer(overrides: [scoringRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  final raceSet = RaceResultSet(raceId: 3, results: [
    _result(raceId: 3, userId: 42, rank: 1),
    _result(raceId: 3, userId: 99, rank: 2, finished: false, distanceKm: 4.1, total: 210),
  ]);

  test('raceResultView: raceId 있으면 getRaceResult 만 쓰고 userId 로 내 행 식별', () async {
    final repo = _FakeScoringRepository(
      myResults: const MyResultsPage(items: [], total: 0),
      raceResult: raceSet,
    );
    final c = _container(repo);

    final view = await c.read(raceResultViewProvider((raceId: 3, userId: 42)).future);
    expect(view.mine.userId, 42);
    expect(view.mine.rank, 1);
    expect(view.set.results.length, 2);
    expect(repo.myResultsCalls, 0, reason: 'raceId 직접 조회 — 폴링 없음');
    expect(repo.raceResultCalls, 1);
  });

  test('raceResultView: raceId 없으면 내 최신 기록 폴링 후 그 raceId 로 전체 결과 조회', () async {
    final repo = _FakeScoringRepository(
      myResults: MyResultsPage(items: [_result(raceId: 3, userId: 42, rank: 1)], total: 4),
      raceResult: raceSet,
    );
    final c = _container(repo);

    final view = await c.read(raceResultViewProvider((raceId: null, userId: 42)).future);
    expect(view.mine.raceId, 3);
    expect(view.mine.userId, 42);
    expect(repo.myResultsCalls, greaterThanOrEqualTo(1));
    expect(repo.raceResultCalls, 1);
  });

  test('RunnerStatsSummary.fromPage: 전체수=total, 표본 거리/승수/승률, partial 플래그', () {
    final page = MyResultsPage(items: [
      _result(raceId: 1, userId: 42, rank: 1, distanceKm: 5.0, total: 800),
      _result(raceId: 2, userId: 42, rank: 3, finished: true, distanceKm: 3.0, total: 500),
    ], total: 10);

    final s = RunnerStatsSummary.fromPage(page);
    expect(s.raceCount, 10);
    expect(s.totalDistanceKm, 8.0);
    expect(s.winCount, 1);
    expect(s.totalScore, 1300);
    expect(s.partial, isTrue, reason: '표본 2 < total 10');
    // partial 이면 승률 분모는 표본 수(2) → 1/2 = 0.5
    expect(s.winRate, 0.5);
  });

  test('RunnerStatsSummary.fromPage: 표본==total 이면 partial=false, 승률 전체 기준', () {
    final page = MyResultsPage(items: [
      _result(raceId: 1, userId: 42, rank: 1),
      _result(raceId: 2, userId: 42, rank: 2),
    ], total: 2);
    final s = RunnerStatsSummary.fromPage(page);
    expect(s.partial, isFalse);
    expect(s.winRate, 0.5);
  });
}
