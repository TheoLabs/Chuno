import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/tokens.dart';
import '../../core/storage/token_store.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// 인증 세션 컨트롤러. 토큰 보유 여부로 로그인 상태를 판단하고,
/// 로그인/로그아웃/세션 만료를 처리한다.
///
/// S1-7 범위: 세션 상태·컨트롤러 골격. 화면 배선은 S1-8 이후.
class AuthController extends Notifier<AuthState> {
  TokenStore get _tokenStore => ref.read(tokenStoreProvider);
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // 최초엔 미확정 상태로 시작하고, 비동기로 토큰 유무를 확인한다.
    _restore();
    return const AuthState.unknown();
  }

  Future<void> _restore() async {
    final hasTokens = await _tokenStore.hasTokens();
    state = hasTokens
        ? const AuthState.authenticated()
        : const AuthState.unauthenticated();
  }

  /// 이미 발급된 토큰 쌍으로 세션을 확립한다.(로그인 성공 후)
  Future<void> establishSession(TokenPair tokens) async {
    await _tokenStore.save(tokens);
    state = const AuthState.authenticated();
  }

  /// 소셜 자격으로 로그인.(실제 화면 연동은 S1-8 이후)
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

  /// 사용자 로그아웃. 서버 세션 무효화(best-effort) + 로컬 토큰 삭제.
  Future<void> logout() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      await _authRepository.logout(refresh);
    }
    await _tokenStore.clear();
    state = const AuthState.unauthenticated();
  }

  /// refresh 최종 실패 등으로 세션이 만료됐을 때 인터셉터가 호출.
  void onSessionExpired() {
    state = const AuthState.unauthenticated();
  }
}
