/// 환경 설정 — baseUrl 등. dev 기본값은 로컬 백엔드(core-api)를 가리킨다.
/// 빌드시 `--dart-define=CHUNO_API_BASE_URL=...` 로 덮어쓸 수 있다.
class Env {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const Env({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  /// 개발 기본값. 로컬 core-api(전역 프리픽스 `/api`)를 가리킨다.
  ///
  /// - iOS 시뮬레이터: `http://localhost:3000/api` (기본값).
  /// - Android 에뮬레이터: 호스트 loopback 이 다르므로
  ///   `--dart-define=CHUNO_API_BASE_URL=http://10.0.2.2:3000/api` 로 오버라이드해야 한다.
  static const Env dev = Env(
    baseUrl: 'http://localhost:3000/api',
  );

  /// dart-define 오버라이드를 반영한 현재 환경.
  static Env current() {
    const override = String.fromEnvironment('CHUNO_API_BASE_URL');
    if (override.isEmpty) return dev;
    return Env(
      baseUrl: override,
      connectTimeout: dev.connectTimeout,
      receiveTimeout: dev.receiveTimeout,
    );
  }
}

/// API 경로 상수. baseUrl 이 이미 `/api` 프리픽스를 포함하므로
/// 여기서는 프리픽스 이후 경로만 둔다. (최종 예: `/api/auth/social-login`)
class ApiPaths {
  ApiPaths._();
  static const String socialLogin = '/auth/social-login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/users/me';
  static const String checkNickname = '/users/check-nickname';
  static const String onboard = '/users/onboard';
  static const String legalDocuments = '/legal-documents';
  static const String rooms = '/rooms';
  static const String rankings = '/rankings';
  static const String myResults = '/users/me/results';
  static String raceResult(int raceId) => '/races/$raceId/result';
}
