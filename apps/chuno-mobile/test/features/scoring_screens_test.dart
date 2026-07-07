// 랭킹/기록 화면이 fake 저장소 데이터로 상태를 실제 반영하는지 검증
// (내 순위 하이라이트·점수 포맷·통계 집계·목록 매핑).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/scoring/scoring_models.dart';
import 'package:chuno_mobile/features/scoring/scoring_providers.dart';
import 'package:chuno_mobile/features/scoring/scoring_repository.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';
import 'package:chuno_mobile/screens/history_screen.dart';
import 'package:chuno_mobile/screens/ranking_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

RaceResultModel _result({required int rank, bool finished = true, double distanceKm = 5.0, int total = 800}) =>
    RaceResultModel(
      id: rank, raceId: rank, userId: 42, finished: finished, distanceKm: distanceKm,
      finishTime: finished ? 722.0 : null, rank: rank, total: total, rankScore: 300,
      distanceScore: 200, finishBonus: finished ? 220 : 0, marginScore: 80, pointsAwarded: 80,
    );

class _FakeScoring implements ScoringRepository {
  final RankingBoard board;
  final MyResultsPage page;
  _FakeScoring({required this.board, required this.page});

  @override
  Future<RankingBoard> getRankings({required RankingScope scope}) async => board;
  @override
  Future<MyResultsPage> getMyResults({int? page, int? limit}) async => this.page;
  @override
  Future<RaceResultSet> getRaceResult(int raceId) async => RaceResultSet(raceId: raceId, results: const []);
}

class _FakeUser implements UserRepository {
  final MeModel me;
  _FakeUser(this.me);
  @override
  Future<MeModel> getMe() async => me;
  @override
  Future<bool> checkNickname(String nickname) async => true;
  @override
  Future<void> onboard({required String nickname, required String level, required List<int> legalDocumentIds}) async {}
}

Widget _app(Widget child, {required ScoringRepository scoring, MeModel? me}) => ProviderScope(
      overrides: [
        scoringRepositoryProvider.overrideWithValue(scoring),
        userRepositoryProvider.overrideWithValue(_FakeUser(me ?? const MeModel(id: 'u1', nickname: '테오', tier: 'gold'))),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: SafeArea(child: child))),
    );

void main() {
  testWidgets('ranking: 내 순위 카드·점수 천단위 포맷·내 행 하이라이트, 타 러너는 러너#id', (tester) async {
    final board = RankingBoard(
      scope: RankingScope.all,
      total: 128,
      me: const RankingEntry(rank: 2, userId: 42, score: 19500),
      items: const [
        RankingEntry(rank: 1, userId: 10, score: 21050),
        RankingEntry(rank: 2, userId: 42, score: 19500),
        RankingEntry(rank: 3, userId: 11, score: 18320),
      ],
    );
    await tester.pumpWidget(_app(const RankingScreen(),
        scoring: _FakeScoring(board: board, page: const MyResultsPage(items: [], total: 0))));
    await tester.pumpAndSettle();

    // 내 닉네임(me 카드 + 내 행 모두) 노출, 타 러너는 러너#id.
    expect(find.text('테오'), findsWidgets);
    expect(find.text('러너 #10'), findsOneWidget);
    expect(find.text('러너 #11'), findsOneWidget);
    // 점수 천단위 포맷.
    expect(find.text('21,050점'), findsOneWidget);
    expect(find.text('19,500점'), findsOneWidget);
  });

  testWidgets('ranking: 참가 이력 없으면(me null) 순위 없음 안내', (tester) async {
    final board = RankingBoard(scope: RankingScope.all, total: 0, me: null, items: const []);
    await tester.pumpWidget(_app(const RankingScreen(),
        scoring: _FakeScoring(board: board, page: const MyResultsPage(items: [], total: 0))));
    await tester.pumpAndSettle();
    expect(find.text('아직 순위가 없어요'), findsOneWidget);
  });

  testWidgets('history: 통계 집계(누적km·경기수·승률) + 기록 목록 매핑', (tester) async {
    final page = MyResultsPage(items: [
      _result(rank: 1, distanceKm: 5.0),
      _result(rank: 4, finished: false, distanceKm: 3.0, total: 210),
    ], total: 2);
    final board = RankingBoard(scope: RankingScope.all, total: 0, items: const []);
    await tester.pumpWidget(_app(const HistoryScreen(), scoring: _FakeScoring(board: board, page: page)));
    await tester.pumpAndSettle();

    // 누적 8km, 경기 2, 승률 50%(2건 중 1승).
    expect(find.text('8'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    // 완주/미완주 행 타이틀·등수 태그.
    expect(find.text('🏁 완주 5.00km'), findsOneWidget);
    expect(find.text('🏳️ 미완주 3.00km'), findsOneWidget);
    expect(find.text('1위'), findsOneWidget);
    expect(find.text('4위'), findsOneWidget);
  });

  testWidgets('history: 기록 없으면 빈 상태 안내', (tester) async {
    final board = RankingBoard(scope: RankingScope.all, total: 0, items: const []);
    await tester.pumpWidget(_app(const HistoryScreen(),
        scoring: _FakeScoring(board: board, page: const MyResultsPage(items: [], total: 0))));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 경기 기록이 없어요'), findsOneWidget);
  });
}
