import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/token_store.dart';
import 'auth_controller.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// 환경 설정.
final envProvider = Provider<Env>((ref) => Env.current());

/// 보안 KV 저장(테스트에서 override 가능).
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SecureKeyValueStore(),
);

/// 토큰 보안 저장소.
final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(keyValueStoreProvider)),
);

/// 인터셉터 없는 refresh 전용 dio(401→refresh→401 재귀 방지).
final refreshDioProvider = Provider<Dio>(
  (ref) => Dio(buildBaseOptions(ref.watch(envProvider))),
);

/// 인증 원격 저장소(refresh/login/logout 계약).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => HttpAuthRepository(ref.watch(refreshDioProvider)),
);

/// 앱 공통 API 클라이언트. 401 시 authRepository.refresh 로 토큰 회전 후 재시도.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient.build(
    env: ref.watch(envProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    refresher: (refreshToken) =>
        ref.read(authRepositoryProvider).refresh(refreshToken),
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
  return client;
});

/// 인증 세션 상태/컨트롤러. 로그인 여부 분기는 S1-8 에서 이 provider 를 구독한다.
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
