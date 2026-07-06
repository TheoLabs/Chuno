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

/// 거리·제한시간 필터 프리셋(라벨 + min/max). idx 0 = 전체(필터 없음).
class RangePreset {
  final String label;
  final int? min;
  final int? max;
  const RangePreset(this.label, {this.min, this.max});
}

/// 목표 거리(km) 필터 프리셋.
const List<RangePreset> distancePresets = [
  RangePreset('거리 전체'),
  RangePreset('5km 이하', max: 5),
  RangePreset('5km 초과', min: 6),
];

/// 제한 시간(분) 필터 프리셋.
const List<RangePreset> limitPresets = [
  RangePreset('제한 전체'),
  RangePreset('30분 이하', max: 30),
  RangePreset('30분 초과', min: 31),
];

/// 홈 방목록 필터 상태(선택된 프리셋 인덱스).
class RoomFilters {
  final int distanceIdx;
  final int limitIdx;
  const RoomFilters({this.distanceIdx = 0, this.limitIdx = 0});

  bool get distanceActive => distanceIdx != 0;
  bool get limitActive => limitIdx != 0;

  RangePreset get distance => distancePresets[distanceIdx];
  RangePreset get limit => limitPresets[limitIdx];

  RoomFilters copyWith({int? distanceIdx, int? limitIdx}) => RoomFilters(
        distanceIdx: distanceIdx ?? this.distanceIdx,
        limitIdx: limitIdx ?? this.limitIdx,
      );
}
