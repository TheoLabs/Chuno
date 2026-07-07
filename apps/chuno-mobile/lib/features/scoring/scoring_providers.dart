import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'scoring_models.dart';
import 'scoring_repository.dart';

/// 스코어링 원격 저장소. 인증 API 클라이언트(apiClientProvider)를 사용한다.
/// 테스트에서는 fake 로 override 한다.
final scoringRepositoryProvider = Provider<ScoringRepository>(
  (ref) => HttpScoringRepository(ref.watch(apiClientProvider)),
);

/// 랭킹 보드(`GET /rankings?scope=`) — 세그먼트(범위)별. 화면에서 AsyncValue 로 소비.
/// 재시도/새로고침은 `ref.invalidate(rankingProvider(scope))`.
final rankingProvider = FutureProvider.family<RankingBoard, RankingScope>(
  (ref, scope) => ref.watch(scoringRepositoryProvider).getRankings(scope: scope),
);

/// 통계 집계용 기록 표본 상한(MVP) — 전용 통계 엔드포인트가 없어 최근 N건으로 근사.
const int kStatsSampleLimit = 100;

/// 내 기록 목록(`GET /users/me/results`). 통계 집계 + 기록 화면 목록에 공용.
/// 표본 상한([kStatsSampleLimit]) 한 페이지를 최신순으로 받는다.
final myResultsProvider = FutureProvider<MyResultsPage>(
  (ref) => ref.watch(scoringRepositoryProvider).getMyResults(limit: kStatsSampleLimit),
);

/// 누적 통계 요약(프로필·기록 화면). 내 기록 표본에서 집계.
final runnerStatsProvider = FutureProvider<RunnerStatsSummary>((ref) async {
  final page = await ref.watch(myResultsProvider.future);
  return RunnerStatsSummary.fromPage(page);
});

/// 경주 결과 화면 인자 — raceId(있으면 직접 조회) + 내 userId(내 행 식별).
typedef RaceResultArgs = ({int? raceId, int userId});

/// 결과 화면 뷰모델. raceId 가 있으면 그 경주 결과를 바로 조회하고,
/// 없으면(라이브 종료 직후 raceId 미확보) 내 최신 기록을 폴백 폴링해 raceId 를 확보한다.
///
/// 결과는 RaceFinished 를 비동기 소비해 적재되므로, 라이브 종료 직후엔 아직 미기록일 수 있다 →
/// 몇 차례 지연 재시도(폴링)로 적재를 기다린다.
final raceResultViewProvider =
    FutureProvider.autoDispose.family<RaceResultView, RaceResultArgs>((ref, args) async {
  final repo = ref.watch(scoringRepositoryProvider);

  int? raceId = args.raceId;
  RaceResultModel? mine;

  if (raceId == null) {
    // 라이브 종료 직후 — 내 최신 기록이 적재될 때까지 폴링(비동기 결과 적재 대기).
    const attempts = 6;
    for (var i = 0; i < attempts; i++) {
      final page = await repo.getMyResults(limit: 1);
      if (page.items.isNotEmpty) {
        mine = page.items.first;
        raceId = mine.raceId;
        break;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 500 + i * 400));
      }
    }
    if (raceId == null) {
      throw StateError('결과가 아직 집계되지 않았어요');
    }
  }

  final set = await repo.getRaceResult(raceId);
  mine ??= set.forUser(args.userId);
  if (mine == null) {
    throw StateError('내 결과를 찾지 못했어요');
  }
  return RaceResultView(set: set, mine: mine);
});
