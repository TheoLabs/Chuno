import 'geo.dart';

/// RunTracker 노이즈필터 파라미터(S3-1). 기본값은 러닝(도보~달리기) 기준 보수적.
class RunTrackerConfig {
  /// (a) 저정확도 컷 — 수평정확도(m)가 이 값을 넘는 샘플은 신뢰 불가로 버린다.
  /// 도심 GPS 튐/실내 진입 시의 큰 오차를 배제한다.
  final double maxAccuracyM;

  /// (b) 드리프트 컷 — 직전 수용점 대비 이동거리(m)가 이 값 미만이면 무시한다.
  /// 정지 상태의 GPS 미세 흔들림이 거리로 누적되는 것을 막는다.
  final double minStepM;

  /// (c) 순간이동 컷 — 인접 샘플 간 속도(km/h)가 이 값을 초과하면 GPS 점프로 보고 버린다.
  /// 백엔드 안티치트 상한(24km/h)과 동일 계열이나, 클라 필터는 자동차 이동/좌표 튐까지
  /// 넉넉히 배제하도록 더 크게 잡는다(정상 러닝은 영향 없음).
  final double maxSpeedKmh;

  const RunTrackerConfig({
    this.maxAccuracyM = 30.0,
    this.minStepM = 3.0,
    this.maxSpeedKmh = 32.0,
  });
}

/// 샘플 반영 결과(테스트·디버깅용). 수락 여부와 버린 사유를 담는다.
enum RunSampleOutcome {
  accepted, // 거리 누적에 반영됨
  seeded, // 최초 기준점(거리 변화 없음)
  lowAccuracy, // (a) 저정확도로 버림
  drift, // (b) 최소 이동 미만(정지 드리프트)로 버림
  teleport, // (c) 비현실 속도(점프)로 버림
}

/// 누적 거리 트래커(S3-1) — 순수 로직. 위치 스트림 소스와 분리해 fake 로 유닛테스트한다.
///
/// **좌표는 내부 계산에만 쓰고 외부로 노출하지 않는다.** 노출값은 누적 거리(km)뿐이다.
/// 각 샘플에 3중 노이즈필터를 적용하고, 통과한 인접 수용점 사이 거리를 Haversine 으로 누적한다.
class RunTracker {
  final RunTrackerConfig config;

  GeoSample? _lastAccepted;
  double _distanceKm = 0.0;

  RunTracker({this.config = const RunTrackerConfig()});

  /// 현재 누적 거리(km). UI/소켓에 보고하는 유일한 값.
  double get distanceKm => _distanceKm;

  /// 샘플 1개 반영. 누적 거리를 갱신하고 처리 결과를 돌려준다.
  RunSampleOutcome add(GeoSample s) {
    // (a) 저정확도 컷 — 기준점조차 못 되게 버린다(오염 방지).
    if (s.accuracy.isNaN || s.accuracy > config.maxAccuracyM) {
      return RunSampleOutcome.lowAccuracy;
    }

    final prev = _lastAccepted;
    if (prev == null) {
      _lastAccepted = s;
      return RunSampleOutcome.seeded;
    }

    final stepKm =
        haversineKm(prev.latitude, prev.longitude, s.latitude, s.longitude);
    final stepM = stepKm * 1000.0;

    // (b) 드리프트 컷 — 정지 시 미세 흔들림 누적 방지. 기준점은 갱신하지 않는다
    // (움직이기 시작하면 원래 기준점부터의 실제 이동이 minStep 을 넘겨 반영되게).
    if (stepM < config.minStepM) {
      return RunSampleOutcome.drift;
    }

    // (c) 순간이동 컷 — Δt 대비 속도가 상한 초과면 GPS 점프. 기준점 유지.
    final dtMs = s.timestamp.difference(prev.timestamp).inMilliseconds;
    if (dtMs <= 0) {
      return RunSampleOutcome.teleport;
    }
    final speedKmh = stepKm / (dtMs / 3600000.0);
    if (speedKmh > config.maxSpeedKmh) {
      return RunSampleOutcome.teleport;
    }

    _distanceKm += stepKm;
    _lastAccepted = s;
    return RunSampleOutcome.accepted;
  }

  /// 재시작(재사용 시). 누적/기준점 초기화.
  void reset() {
    _lastAccepted = null;
    _distanceKm = 0.0;
  }
}
