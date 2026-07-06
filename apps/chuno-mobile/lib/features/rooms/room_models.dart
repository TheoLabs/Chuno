/// 방(Room) 도메인 모델 — core-api `GET /rooms` list item(GeneralRoomResponseDto) 매핑.
///
/// list 응답 필드: id, hostUserId, name, targetDistance, limitMinutes,
/// maxParticipants, scheduledStartOn('YYYY-MM-DD HH:mm:ss'), status,
/// currentParticipantsCount, isHost, createdAt, updatedAt.
library;

/// 방 상태(core-api RoomStatus enum).
enum RoomStatus {
  recruiting, // 모집중
  starting, // 곧 시작(예약 시각 임박)
  live, // 진행 중
  finished, // 종료
  cancelled; // 취소(정원 미달 등)

  static RoomStatus fromWire(String? s) => switch (s) {
        'recruiting' => recruiting,
        'starting' => starting,
        'live' => live,
        'finished' => finished,
        'cancelled' => cancelled,
        _ => recruiting,
      };

  /// 서버 전송/쿼리용 문자열(enum name 과 동일).
  String get wire => name;
}

class RoomModel {
  /// 서버 PK(정수). 상세 조회/취소 시 이 값을 경로로 쓴다.
  final int id;
  final String hostUserId;
  final String name;

  /// 목표 거리(정수 km).
  final int targetDistance;

  /// 제한 시간(분).
  final int limitMinutes;
  final int maxParticipants;

  /// 예약 시작 시각 원본 문자열('YYYY-MM-DD HH:mm:ss', KST 비즈니스 시각).
  final String scheduledStartOn;
  final RoomStatus status;
  final int currentParticipantsCount;

  /// 내가 방장인지.
  final bool isHost;

  const RoomModel({
    required this.id,
    required this.hostUserId,
    required this.name,
    required this.targetDistance,
    required this.limitMinutes,
    required this.maxParticipants,
    required this.scheduledStartOn,
    required this.status,
    required this.currentParticipantsCount,
    required this.isHost,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      hostUserId: json['hostUserId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      targetDistance: (json['targetDistance'] as num?)?.toInt() ?? 0,
      limitMinutes: (json['limitMinutes'] as num?)?.toInt() ?? 0,
      maxParticipants: (json['maxParticipants'] as num?)?.toInt() ?? 0,
      scheduledStartOn: json['scheduledStartOn']?.toString() ?? '',
      status: RoomStatus.fromWire(json['status']?.toString()),
      currentParticipantsCount:
          (json['currentParticipantsCount'] as num?)?.toInt() ?? 0,
      isHost: json['isHost'] == true,
    );
  }

  /// 남은 자리(표시용).
  int get remainingSlots =>
      (maxParticipants - currentParticipantsCount).clamp(0, maxParticipants);

  /// 예약 시작 시각(파싱). 'YYYY-MM-DD HH:mm:ss' → naive 로컬 DateTime.
  DateTime? get startAt {
    final s = scheduledStartOn.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.contains('T') ? s : s.replaceFirst(' ', 'T'));
  }

  /// 'HH:mm 시작' 라벨(파싱 실패 시 원본 폴백).
  String get startLabel {
    final at = startAt;
    if (at == null) return scheduledStartOn.isEmpty ? '시작 미정' : scheduledStartOn;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(at.hour)}:${p(at.minute)} 시작';
  }

  /// 시작까지 남은 카운트다운 라벨. 이미 지났거나 미정이면 null.
  String? get countdownLabel {
    final at = startAt;
    if (at == null) return null;
    final diff = at.difference(DateTime.now());
    if (diff.isNegative) return null;
    if (diff.inHours >= 1) return '${diff.inHours}시간 후';
    final m = diff.inMinutes;
    if (m >= 1) return '$m분 후';
    return '곧 출발';
  }
}

/// 필터 레인지바 경계 상수(정수 km·분). 기본 필터 = 전체 범위(미적용).
const int kDistanceMin = 1; // 목표 거리 최소(km)
const int kDistanceMax = 20; // 목표 거리 최대(km)
const int kLimitMin = 10; // 제한 시간 최소(분)
const int kLimitMax = 120; // 제한 시간 최대(분)
const int kLimitStep = 5; // 제한 시간 눈금 간격(분)

/// 홈 방목록 필터 상태(거리·제한시간 각각 min/max 범위).
///
/// 기본값 = 전체 범위 → 필터 미적용. 서버 쿼리에는 전체 범위일 때 null 을,
/// 부분 범위일 때 현재 min/max(정수)를 전달한다(query* 게터).
class RoomFilters {
  final int distanceMin;
  final int distanceMax;
  final int limitMin;
  final int limitMax;
  const RoomFilters({
    this.distanceMin = kDistanceMin,
    this.distanceMax = kDistanceMax,
    this.limitMin = kLimitMin,
    this.limitMax = kLimitMax,
  });

  /// 거리 범위가 전체 경계와 다르면 활성(필터 적용).
  bool get distanceActive =>
      distanceMin != kDistanceMin || distanceMax != kDistanceMax;

  /// 제한 시간 범위가 전체 경계와 다르면 활성(필터 적용).
  bool get limitActive => limitMin != kLimitMin || limitMax != kLimitMax;

  /// 서버 쿼리용 값 — 전체 범위면 null(미적용), 아니면 현재 min/max.
  int? get queryDistanceMin => distanceActive ? distanceMin : null;
  int? get queryDistanceMax => distanceActive ? distanceMax : null;
  int? get queryLimitMin => limitActive ? limitMin : null;
  int? get queryLimitMax => limitActive ? limitMax : null;

  /// 칩 라벨 — 미적용이면 '거리', 적용이면 '3–10km'.
  String get distanceLabel =>
      distanceActive ? '$distanceMin–${distanceMax}km' : '거리';

  /// 칩 라벨 — 미적용이면 '제한시간', 적용이면 '20–60분'.
  String get limitLabel => limitActive ? '$limitMin–$limitMax분' : '제한시간';

  RoomFilters copyWith({
    int? distanceMin,
    int? distanceMax,
    int? limitMin,
    int? limitMax,
  }) =>
      RoomFilters(
        distanceMin: distanceMin ?? this.distanceMin,
        distanceMax: distanceMax ?? this.distanceMax,
        limitMin: limitMin ?? this.limitMin,
        limitMax: limitMax ?? this.limitMax,
      );
}
