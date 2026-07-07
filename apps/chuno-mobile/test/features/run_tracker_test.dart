// RunTracker 노이즈필터·거리누적 유닛테스트 (S3-1) — 좌표는 로컬 계산 전용.
import 'package:flutter_test/flutter_test.dart';

import 'package:chuno_mobile/features/race/geo.dart';
import 'package:chuno_mobile/features/race/run_tracker.dart';

/// 서울 인근 기준점. 위도 1도 ≈ 111km.
const _lat0 = 37.5000;
const _lon0 = 127.0000;

GeoSample sample(double lat, double lon,
    {double accuracy = 5, required int tMs}) {
  return GeoSample(
    latitude: lat,
    longitude: lon,
    accuracy: accuracy,
    timestamp: DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: true),
  );
}

void main() {
  group('haversineKm', () {
    test('위도 0.0001도 ≈ 11m 근사', () {
      final km = haversineKm(_lat0, _lon0, _lat0 + 0.0001, _lon0);
      expect(km * 1000, closeTo(11.13, 0.3));
    });

    test('같은 점은 0', () {
      expect(haversineKm(_lat0, _lon0, _lat0, _lon0), 0);
    });
  });

  group('RunTracker 노이즈필터', () {
    test('(a) 저정확도 샘플은 버린다(기준점도 안 됨)', () {
      final t = RunTracker();
      expect(t.add(sample(_lat0, _lon0, accuracy: 100, tMs: 0)),
          RunSampleOutcome.lowAccuracy);
      // 이후 정상 이동해도 첫 유효점이 기준점이 될 뿐 거리 0.
      expect(t.add(sample(_lat0, _lon0, accuracy: 5, tMs: 1000)),
          RunSampleOutcome.seeded);
      expect(t.distanceKm, 0);
    });

    test('(b) 정지 드리프트(최소 이동 미만)는 누적하지 않는다', () {
      final t = RunTracker();
      t.add(sample(_lat0, _lon0, tMs: 0)); // seed
      // 0.00001도 ≈ 1.1m < minStep(3m) → drift, 누적 0.
      for (var i = 1; i <= 10; i++) {
        final r = t.add(sample(_lat0 + 0.00001 * (i.isEven ? 1 : -1), _lon0,
            tMs: 1000 * i));
        expect(r, RunSampleOutcome.drift);
      }
      expect(t.distanceKm, 0);
    });

    test('(c) 순간이동(비현실 속도)은 버린다', () {
      final t = RunTracker();
      t.add(sample(_lat0, _lon0, tMs: 0)); // seed
      // 0.01도 ≈ 1.1km 를 1초에 → 4000km/h → teleport.
      expect(t.add(sample(_lat0 + 0.01, _lon0, tMs: 1000)),
          RunSampleOutcome.teleport);
      expect(t.distanceKm, 0);
    });

    test('Δt<=0 인 전진 샘플은 순간이동 처리', () {
      final t = RunTracker();
      t.add(sample(_lat0, _lon0, tMs: 5000)); // seed
      expect(t.add(sample(_lat0 + 0.0002, _lon0, tMs: 5000)),
          RunSampleOutcome.teleport);
    });
  });

  group('RunTracker 거리누적', () {
    test('실이동 시 합리적으로 증가한다', () {
      final t = RunTracker();
      // 0.0001도(~11m)씩 10스텝, 각 2초 간격(≈20km/h, 상한 이하).
      double lat = _lat0;
      var tMs = 0;
      var accepted = 0;
      t.add(sample(lat, _lon0, tMs: tMs)); // seed
      for (var i = 0; i < 10; i++) {
        lat += 0.0001;
        tMs += 2000;
        if (t.add(sample(lat, _lon0, tMs: tMs)) == RunSampleOutcome.accepted) {
          accepted++;
        }
      }
      expect(accepted, 10);
      // 총 이동 ≈ 111m. 오차 허용.
      expect(t.distanceKm * 1000, closeTo(111.3, 3));
    });

    test('정지(드리프트) 구간이 섞여도 실이동만 누적된다', () {
      final t = RunTracker();
      var tMs = 0;
      t.add(sample(_lat0, _lon0, tMs: tMs));
      // 실이동 1스텝(~11m)
      tMs += 3000;
      t.add(sample(_lat0 + 0.0001, _lon0, tMs: tMs));
      final afterMove = t.distanceKm;
      // 정지 드리프트 20회
      for (var i = 0; i < 20; i++) {
        tMs += 1000;
        t.add(sample(_lat0 + 0.0001 + 0.00001 * (i.isEven ? 1 : -1), _lon0,
            tMs: tMs));
      }
      // 드리프트로 거리 변화 없음.
      expect(t.distanceKm, closeTo(afterMove, 1e-9));
    });

    test('reset 후 누적 초기화', () {
      final t = RunTracker();
      t.add(sample(_lat0, _lon0, tMs: 0));
      t.add(sample(_lat0 + 0.0002, _lon0, tMs: 3000));
      expect(t.distanceKm, greaterThan(0));
      t.reset();
      expect(t.distanceKm, 0);
      expect(t.add(sample(_lat0, _lon0, tMs: 4000)), RunSampleOutcome.seeded);
    });
  });
}
