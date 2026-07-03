/// 러닝 레벨. 앱 표시(입문/중급/고급) ↔ 서버 계약(beginner/intermediate/advanced).
enum RunnerLevel {
  beginner('beginner', '입문'),
  intermediate('intermediate', '중급'),
  advanced('advanced', '고급');

  final String wire;
  final String label;
  const RunnerLevel(this.wire, this.label);

  /// 온보딩 세그먼트 인덱스(0=입문,1=중급,2=고급) → 레벨.
  static RunnerLevel fromIndex(int i) =>
      RunnerLevel.values[i.clamp(0, RunnerLevel.values.length - 1)];

  /// 서버 계약 문자열(beginner/intermediate/advanced) → 레벨. 미매칭이면 null.
  static RunnerLevel? fromWire(String? wire) {
    for (final l in RunnerLevel.values) {
      if (l.wire == wire) return l;
    }
    return null;
  }
}

/// 러너 티어. 서버 계약(bronze..diamond) ↔ 앱 표시 라벨/이모지.
/// 표시 색은 참가자 팔레트에서 매핑(프로필 화면 참고).
enum RunnerTier {
  bronze('bronze', '🥉 브론즈'),
  silver('silver', '🥈 실버'),
  gold('gold', '🥇 골드'),
  platinum('platinum', '🛡 플래티넘'),
  diamond('diamond', '💎 다이아');

  final String wire;
  final String label;
  const RunnerTier(this.wire, this.label);

  /// 서버 계약 문자열 → 티어. 미매칭이면 null.
  static RunnerTier? fromWire(String? wire) {
    for (final t in RunnerTier.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// `GET /users/me` 응답의 사용자 프로필. [onboardedOn] 이 null 이면 온보딩 미완.
class MeModel {
  final String id;
  final String? nickname;
  final String? level;
  final String? tier;
  final String? profileImageFileId;
  final String? bio;
  final DateTime? onboardedOn;

  const MeModel({
    required this.id,
    this.nickname,
    this.level,
    this.tier,
    this.profileImageFileId,
    this.bio,
    this.onboardedOn,
  });

  /// 온보딩 완료 여부 — 서버 권위 판정.
  bool get isOnboarded => onboardedOn != null;

  factory MeModel.fromJson(Map<String, dynamic> json) {
    return MeModel(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname'] as String?,
      level: json['level'] as String?,
      tier: json['tier'] as String?,
      profileImageFileId: json['profileImageFileId'] as String?,
      bio: json['bio'] as String?,
      onboardedOn: _parseDate(json['onboardedOn']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }
}
