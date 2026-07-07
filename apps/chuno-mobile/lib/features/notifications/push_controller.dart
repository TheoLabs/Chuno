import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'device_token_repository.dart';
import 'push_service.dart';

/// 푸시 등록 상태 — Firebase 사용가능 여부 + 권한 + 서버에 등록된 토큰.
class PushState {
  final bool available;
  final PushPermission permission;

  /// 서버에 등록 성공한 최신 토큰(로그아웃 시 이 값으로 DELETE). null=미등록.
  final String? registeredToken;

  const PushState({
    this.available = false,
    this.permission = PushPermission.notDetermined,
    this.registeredToken,
  });

  bool get isRegistered => registeredToken != null;

  PushState copyWith({
    bool? available,
    PushPermission? permission,
    String? registeredToken,
    bool clearToken = false,
  }) =>
      PushState(
        available: available ?? this.available,
        permission: permission ?? this.permission,
        registeredToken:
            clearToken ? null : (registeredToken ?? this.registeredToken),
      );
}

/// 푸시 수신 서비스 provider(FCM 실구현). 테스트는 fake 로 override.
final pushServiceProvider =
    Provider<PushService>((ref) => FirebasePushService());

/// device-token 등록/해제 원격 저장소. 인증 API 클라이언트 사용.
final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>(
  (ref) => HttpDeviceTokenRepository(ref.watch(apiClientProvider)),
);

/// 푸시 등록 생명주기 컨트롤러 (S5-2).
/// - [register]: 로그인/앱시작 시 초기화 → 권한 요청 → 토큰 서버 등록 + 회전 재등록 구독.
/// - [unregister]: 로그아웃 시 등록 토큰 서버 해제.
///
/// Firebase 미설정이면 initialize 가 graceful 실패(available=false)해 아무 것도 하지 않는다.
class PushController extends Notifier<PushState> {
  StreamSubscription<String>? _refreshSub;
  bool _initialized = false;

  PushService get _service => ref.read(pushServiceProvider);
  DeviceTokenRepository get _repo => ref.read(deviceTokenRepositoryProvider);

  @override
  PushState build() {
    ref.onDispose(() => _refreshSub?.cancel());
    return const PushState();
  }

  /// 초기화 + 토큰 등록. 멱등 — 이미 초기화됐으면 재초기화하지 않는다.
  Future<void> register() async {
    if (_initialized) return;
    _initialized = true;

    final init = await _service.initialize();
    state = PushState(available: init.available, permission: init.permission);
    if (!init.available) return;

    final token = init.token;
    if (token != null && init.permission == PushPermission.granted) {
      await _registerToken(token);
    }
    // 토큰 회전 시 서버 재등록(1회 구독).
    _refreshSub ??= _service.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _registerToken(String token) async {
    try {
      await _repo.register(token: token, platform: _service.platform);
      state = state.copyWith(registeredToken: token);
    } catch (_) {
      // graceful — 네트워크 실패 등. 다음 회전/재시작 때 재시도.
    }
  }

  /// 로그아웃 시 등록 토큰 해제. 초기화 상태는 리셋해 재로그인 시 다시 등록되게 한다.
  Future<void> unregister() async {
    final token = state.registeredToken;
    if (token != null) {
      try {
        await _repo.unregister(token);
      } catch (_) {/* graceful */}
    }
    await _refreshSub?.cancel();
    _refreshSub = null;
    _initialized = false;
    state = state.copyWith(clearToken: true);
  }
}

/// 푸시 등록 컨트롤러 provider.
final pushControllerProvider =
    NotifierProvider<PushController, PushState>(PushController.new);
