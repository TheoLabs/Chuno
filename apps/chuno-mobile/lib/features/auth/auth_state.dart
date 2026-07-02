/// 인증 세션 상태. 앱 시작 시 [unknown] → 토큰 유무 확인 후 확정.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;

  /// 온보딩 완료 여부. authenticated 일 때만 의미가 있다.
  /// 서버 `GET /users/me` 의 `onboardedOn` 으로 판정한다.(AuthController 참고)
  final bool onboarded;

  const AuthState(this.status, {this.onboarded = false});

  const AuthState.unknown()
      : status = AuthStatus.unknown,
        onboarded = false;
  const AuthState.authenticated({this.onboarded = false})
      : status = AuthStatus.authenticated;
  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        onboarded = false;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  /// 인증 완료 + 온보딩 미완 → 온보딩 화면으로 보내야 하는 상태.
  bool get needsOnboarding => isAuthenticated && !onboarded;

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.status == status &&
      other.onboarded == onboarded;

  @override
  int get hashCode => Object.hash(status, onboarded);

  @override
  String toString() => 'AuthState($status, onboarded: $onboarded)';
}
