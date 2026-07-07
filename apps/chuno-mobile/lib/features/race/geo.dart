import 'dart:math' as math;

/// GPS 원시 샘플 — **로컬 계산 전용**. 좌표(lat/lon)는 절대 서버로 전송하지 않고,
/// RunTracker 가 인접 수용점 사이 거리(km)만 누적해 노출한다(프라이버시·백엔드 계약).
class GeoSample {
  final double latitude;
  final double longitude;

  /// 수평 정확도(m). 클수록 부정확 — 노이즈필터 임계 판정에 쓴다.
  final double accuracy;

  /// 샘플 시각. 순간이동(비현실 속도) 판정의 Δt 기준.
  final DateTime timestamp;

  const GeoSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}

const double _earthRadiusKm = 6371.0088;

/// 두 좌표 사이 대권거리(km) — Haversine. 인접 수용점 간 거리 누적에 쓴다.
double haversineKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusKm * c;
}

double _rad(double deg) => deg * math.pi / 180.0;
