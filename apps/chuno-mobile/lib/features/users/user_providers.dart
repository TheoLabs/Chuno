import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'user_models.dart';
import 'user_repository.dart';

/// 사용자(users) 원격 저장소. 인증 API 클라이언트(apiClientProvider)를 사용한다.
/// 테스트에서는 fake 로 override 한다.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => HttpUserRepository(ref.watch(apiClientProvider)),
);

/// 내 프로필(`GET /users/me`) 조회. 프로필 화면에서 AsyncValue 로 소비한다.
/// 재시도는 `ref.invalidate(meProvider)`.
final meProvider = FutureProvider<MeModel>(
  (ref) => ref.watch(userRepositoryProvider).getMe(),
);
