/// 스코어링(랭킹·결과·통계) 도메인 모델 — core-api scoring 프리젠테이션 계약 매핑.
///
/// - 랭킹: `GET /rankings?scope=` → { items:[{rank,userId,score}], total, me }.
/// - 내 기록: `GET /users/me/results` → { items:[RaceResult...], total }.
/// - 경주 결과: `GET /races/:id/result` → { raceId, results:[RaceResult...] }(rank 오름차순).
///
/// 서버가 닉네임/아바타는 랭킹에 싣지 않는다(userId·score·rank만). 표시는 그에 맞춘다.
library;

/// 랭킹 범위 — 앱 세그먼트(전체/주간/월간) ↔ 서버 계약(all/weekly/monthly).
enum RankingScope {
  all('all', '전체'),
  weekly('weekly', '주간'),
  monthly('monthly', '월간');

  final String wire;
  final String label;
  const RankingScope(this.wire, this.label);

  /// 세그먼트 인덱스(0=전체) → 범위.
  static RankingScope fromIndex(int i) =>
      RankingScope.values[i.clamp(0, RankingScope.values.length - 1)];
}

/// 랭킹 1행 — 순위·유저·누적(또는 윈도우) 점수.
class RankingEntry {
  final int rank;
  final int userId;
  final int score;

  const RankingEntry({required this.rank, required this.userId, required this.score});

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toInt() ?? 0,
      );
}

/// 랭킹 보드 — 내 주변 슬라이스(items) + 내 순위(me, 없으면 null) + 전체 인원(total).
class RankingBoard {
  final RankingScope scope;
  final List<RankingEntry> items;
  final int total;
  final RankingEntry? me;

  const RankingBoard({
    required this.scope,
    required this.items,
    required this.total,
    this.me,
  });
}

/// 경주 결과 1명분(4축 점수 평탄 노출) — race-result-response.dto 대응.
class RaceResultModel {
  final int id;
  final int raceId;
  final int userId;
  final bool finished;
  final double distanceKm;
  final double? finishTime; // 완주 소요(초). 미완주(DNF) null.
  final int rank;

  // 4축 점수(서버 권위) + 합계 + 적립 포인트.
  final int total;
  final int rankScore;
  final int distanceScore;
  final int finishBonus;
  final int marginScore;
  final int pointsAwarded;

  const RaceResultModel({
    required this.id,
    required this.raceId,
    required this.userId,
    required this.finished,
    required this.distanceKm,
    required this.finishTime,
    required this.rank,
    required this.total,
    required this.rankScore,
    required this.distanceScore,
    required this.finishBonus,
    required this.marginScore,
    required this.pointsAwarded,
  });

  factory RaceResultModel.fromJson(Map<String, dynamic> j) => RaceResultModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        raceId: (j['raceId'] as num?)?.toInt() ?? 0,
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        finished: j['finished'] == true,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0.0,
        finishTime: (j['finishTime'] as num?)?.toDouble(),
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        rankScore: (j['rankScore'] as num?)?.toInt() ?? 0,
        distanceScore: (j['distanceScore'] as num?)?.toInt() ?? 0,
        finishBonus: (j['finishBonus'] as num?)?.toInt() ?? 0,
        marginScore: (j['marginScore'] as num?)?.toInt() ?? 0,
        pointsAwarded: (j['pointsAwarded'] as num?)?.toInt() ?? 0,
      );
}

/// 내 기록 목록 한 페이지 — items + total(전체 경기 수).
class MyResultsPage {
  final List<RaceResultModel> items;
  final int total;
  const MyResultsPage({required this.items, required this.total});
}

/// 한 경주 전체 결과 — rank 오름차순 러너 전원.
class RaceResultSet {
  final int raceId;
  final List<RaceResultModel> results; // rank 오름차순

  const RaceResultSet({required this.raceId, required this.results});

  /// 특정 유저의 결과 행(없으면 null).
  RaceResultModel? forUser(int userId) {
    for (final r in results) {
      if (r.userId == userId) return r;
    }
    return null;
  }

  /// 시상대(상위 3위) — rank 1..3 순서(없으면 그만큼 짧다).
  List<RaceResultModel> get podium =>
      results.where((r) => r.rank >= 1 && r.rank <= 3).toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
}

/// 경주 결과 화면 뷰모델 — 전체 결과(set) + 내 결과(mine).
class RaceResultView {
  final RaceResultSet set;
  final RaceResultModel mine;
  const RaceResultView({required this.set, required this.mine});
}

/// 누적 통계 요약(프로필·기록 화면용). 전용 엔드포인트가 없어 내 기록 목록에서 집계한다.
/// [partial] 이면 표본([sampleCount])이 total 보다 적어(페이지 상한) 거리/승수 등이 근사임을 뜻한다.
class RunnerStatsSummary {
  final int raceCount; // 전체 경기 수(total)
  final double totalDistanceKm; // 표본 누적 거리
  final int winCount; // 표본 우승(1위) 수
  final int totalScore; // 표본 누적 점수
  final int sampleCount; // 집계에 쓴 표본 수(=items 수)
  final bool partial;

  const RunnerStatsSummary({
    required this.raceCount,
    required this.totalDistanceKm,
    required this.winCount,
    required this.totalScore,
    required this.sampleCount,
    required this.partial,
  });

  /// 승률(0~1). partial 이면 분모를 표본 수로(정확), 아니면 전체 경기 수로.
  double get winRate {
    final base = partial ? sampleCount : raceCount;
    if (base <= 0) return 0;
    return winCount / base;
  }

  /// 기록 목록 페이지에서 요약 집계. total 이 표본보다 크면 partial.
  factory RunnerStatsSummary.fromPage(MyResultsPage page) {
    var dist = 0.0;
    var wins = 0;
    var score = 0;
    for (final r in page.items) {
      dist += r.distanceKm;
      if (r.rank == 1) wins++;
      score += r.total;
    }
    return RunnerStatsSummary(
      raceCount: page.total,
      totalDistanceKm: dist,
      winCount: wins,
      totalScore: score,
      sampleCount: page.items.length,
      partial: page.items.length < page.total,
    );
  }
}
