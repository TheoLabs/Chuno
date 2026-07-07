import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'geo.dart';

/// 위치 권한 취득 결과(S3-2).
enum LocationAuth {
  /// 백그라운드(항상 허용)까지 취득 — 화면 잠금·백그라운드에서도 측정 가능.
  always,

  /// 사용 중에만 허용 — 포그라운드 측정은 되나 백그라운드 지속은 제한.
  whileInUse,

  /// 거부 — 재요청 가능.
  denied,

  /// 영구 거부 — 설정 화면 유도가 필요(openAppSettings).
  deniedForever,

  /// 기기 위치 서비스 자체가 꺼짐.
  serviceDisabled,
}

/// 위치 권한·위치 스트림 접근 계약(S3-1/S3-2). geolocator 실구현과 fake 테스트 더블을 분리한다.
/// RunTracker/컨트롤러는 이 인터페이스에만 의존해 실기기·플러그인 없이 유닛테스트가 가능하다.
abstract class LocationService {
  /// 현재 권한 상태를 요청 없이 조회.
  Future<LocationAuth> currentAuth();

  /// '항상 허용(백그라운드)'까지 단계적으로 요청. iOS 는 whileInUse → always 2단계.
  Future<LocationAuth> ensureAlwaysPermission();

  /// OS 앱 설정 화면 열기(영구 거부 유도용). 성공 여부 반환.
  Future<bool> openSettings();

  /// 고정확도 위치 스트림(백그라운드 지속). 좌표는 GeoSample 로 감싸 로컬 계산에만 쓴다.
  Stream<GeoSample> positions();
}

/// geolocator 기반 실구현. 고정확도 + distanceFilter 로 배터리를 배려하고,
/// iOS 는 pausesLocationUpdatesAutomatically=false + activityType 로 백그라운드 지속을 보장한다.
class GeolocatorLocationService implements LocationService {
  /// distanceFilter(m) — 이 거리 이상 이동해야 새 샘플 방출(배터리 절약, 드리프트 1차 억제).
  final int distanceFilterM;

  const GeolocatorLocationService({this.distanceFilterM = 5});

  @override
  Future<LocationAuth> currentAuth() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAuth.serviceDisabled;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAuth> ensureAlwaysPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAuth.serviceDisabled;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return LocationAuth.deniedForever;
    }
    if (perm == LocationPermission.denied) {
      return LocationAuth.denied;
    }
    // whileInUse 취득 후 '항상 허용(백그라운드)' 승격.
    // Android(11+)는 별도 백그라운드 권한 요청이 필요 → permission_handler 로 요청.
    // iOS 는 whileInUse + UIBackgroundModes(location) + allowBackgroundLocationUpdates 로
    // 활성 세션의 백그라운드 업데이트가 가능하고, 'always' 승격 프롬프트는 OS가 별도 시점에 띄운다.
    if (perm == LocationPermission.whileInUse) {
      if (Platform.isAndroid) {
        final bg = await ph.Permission.locationAlways.request();
        if (bg.isGranted) return LocationAuth.always;
      }
      return LocationAuth.whileInUse;
    }
    return LocationAuth.always; // LocationPermission.always
  }

  @override
  Future<bool> openSettings() => ph.openAppSettings();

  @override
  Stream<GeoSample> positions() {
    final settings = _platformSettings();
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (p) => GeoSample(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        timestamp: p.timestamp,
      ),
    );
  }

  LocationSettings _platformSettings() {
    if (Platform.isAndroid) {
      // Android: 포그라운드 서비스 알림으로 백그라운드 지속(OS 종료 방지).
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '추격전 진행 중',
          notificationText: '뛴 거리를 측정하고 있어요 · 좌표는 전송되지 않아요',
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS: 백그라운드 위치 지속 + 자동 일시정지 해제 + 러닝 활동 타입.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterM,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterM,
    );
  }

  static LocationAuth _map(LocationPermission p) => switch (p) {
        LocationPermission.always => LocationAuth.always,
        LocationPermission.whileInUse => LocationAuth.whileInUse,
        LocationPermission.deniedForever => LocationAuth.deniedForever,
        LocationPermission.denied => LocationAuth.denied,
        LocationPermission.unableToDetermine => LocationAuth.denied,
      };
}
