import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/tokens.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/token_store.dart';
import '../users/user_providers.dart';
import '../users/user_repository.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// 인증 세션 컨트롤러. 토큰 보유 여부로 로그인 상태를 판단하고,
/// 로그인/로그아웃/세션 만료를 처리한다.
///
/// 온보딩 완료 판정은 서버 권위(`GET /users/me` 의 `onboardedOn`)로 하며,
/// 네트워크 실패 시 마지막으로 확인한 값을 로컬 캐시에서 폴백한다.
class AuthController extends Notifier<AuthState> {
  /// 서버 온보딩 판정 결과의 로컬 캐시 키.(오프라인/일시 실패 시 폴백용)
  static const _onboardedCacheKey = 'chuno.session.onboarded';

  TokenStore get _tokenStore => ref.read(tokenStoreProvider);
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  UserRepository get _userRepository => ref.read(userRepositoryProvider);
  KeyValueStore get _kv => ref.read(keyValueStoreProvider);

  @override
  AuthState build() {
    // 최초엔 미확정 상태로 시작하고, 비동기로 토큰 유무를 확인한다.
    restore();
    return const AuthState.unknown();
  }

  /// 부팅 시 세션 복원. 저장된 토큰이 있으면 users/me 로 온보딩 여부를 확정한다.
  Future<void> restore() async {
    final hasTokens = await _tokenStore.hasTokens();
    if (!hasTokens) {
      state = const AuthState.unauthenticated();
      return;
    }
    final onboarded = await _resolveOnboarded();
    state = AuthState.authenticated(onboarded: onboarded);
  }

  /// 이미 발급된 토큰 쌍으로 세션을 확립한다.(로그인 성공 후)
  Future<void> establishSession(TokenPair tokens) async {
    await _tokenStore.save(tokens);
    // 계정이 바뀌었을 수 있으므로 이전 유저의 me 캐시를 버리고 새로 fetch 되게 한다.
    ref.invalidate(meProvider);
    final onboarded = await _resolveOnboarded();
    state = AuthState.authenticated(onboarded: onboarded);
  }

  /// 소셜 자격으로 로그인.(실제 SDK 연동은 S1-9 범위)
  Future<void> login({
    required String provider,
    required String credential,
  }) async {
    final tokens = await _authRepository.login(
      provider: provider,
      credential: credential,
    );
    await establishSession(tokens);
  }

  /// 온보딩 저장 성공 후 호출. 서버가 onboardedOn 을 세팅했으므로 상태를
  /// onboarded=true 로 전이하고 로컬 캐시도 갱신한다.(재실행 시 폴백용)
  Future<void> completeOnboarding() async {
    await _writeCache(true);
    if (state.isAuthenticated) {
      state = const AuthState.authenticated(onboarded: true);
    }
  }

  /// 사용자 로그아웃. 서버 세션 무효화(best-effort) + 로컬 토큰 삭제.
  Future<void> logout() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      await _authRepository.logout(refresh);
    }
    await _tokenStore.clear();
    // 다음 로그인 유저에게 이전 유저 프로필이 노출되지 않도록 me 캐시를 비운다.
    ref.invalidate(meProvider);
    state = const AuthState.unauthenticated();
  }

  /// refresh 최종 실패 등으로 세션이 만료됐을 때 인터셉터가 호출.
  void onSessionExpired() {
    state = const AuthState.unauthenticated();
  }

  /// users/me 로 온보딩 여부를 서버 권위로 확정한다. 실패 시(네트워크 등)
  /// 세션은 유지하고 마지막으로 확인한 로컬 캐시 값으로 폴백한다.
  Future<bool> _resolveOnboarded() async {
    try {
      final me = await _userRepository.getMe();
      await _writeCache(me.isOnboarded);
      return me.isOnboarded;
    } catch (_) {
      // graceful: 세션 유지, 캐시된 값으로 폴백(없으면 미완으로 간주).
      return await _readCache();
    }
  }

  Future<bool> _readCache() async => (await _kv.read(_onboardedCacheKey)) == 'true';

  Future<void> _writeCache(bool v) async =>
      _kv.write(_onboardedCacheKey, v ? 'true' : 'false');
}
