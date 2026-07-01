/// 인증 세션 상태. 앱 시작 시 [unknown] → 토큰 유무 확인 후 확정.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;

  const AuthState(this.status);

  const AuthState.unknown() : status = AuthStatus.unknown;
  const AuthState.authenticated() : status = AuthStatus.authenticated;
  const AuthState.unauthenticated() : status = AuthStatus.unauthenticated;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.status == status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'AuthState($status)';
}
