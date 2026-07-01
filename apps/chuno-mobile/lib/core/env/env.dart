/// 환경 설정 — baseUrl 등. 실제 서버/baseUrl 은 아직 없으므로(placeholder)
/// 개발용 값을 기본으로 둔다. 빌드시 `--dart-define=CHUNO_API_BASE_URL=...` 로 덮어쓸 수 있다.
///
/// S1-5(백엔드 auth) 확정 후 [dev] baseUrl 을 실 서버로 교체한다.
class Env {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  const Env({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
  });

  /// 개발 기본값. baseUrl 은 placeholder — 실 서버 주소가 정해지면 교체한다.
  static const Env dev = Env(
    baseUrl: 'https://api.dev.chuno.local',
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

/// API 경로 상수. 백엔드(S1-5) 확정 전까지의 계약(placeholder).
class ApiPaths {
  ApiPaths._();
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/users/me';
}
