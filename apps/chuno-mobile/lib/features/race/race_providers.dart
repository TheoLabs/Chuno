import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'location_service.dart';
import 'race_socket.dart';

/// roomId 로 '/race' 소켓 채널을 만드는 팩토리. 테스트에서 fake 로 override 한다.
typedef RaceSocketChannelFactory = RaceSocketChannel Function(int roomId);

/// 기본 팩토리 — socket.io(IoRaceSocketChannel). 로비 소켓과 동일 origin/포트,
/// 네임스페이스 '/race', 액세스 토큰은 secure storage 에서 (재)조회한다.
final raceSocketChannelFactoryProvider =
    Provider<RaceSocketChannelFactory>((ref) {
  final env = ref.watch(envProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final origin = _socketOrigin(env.baseUrl);
  return (roomId) => IoRaceSocketChannel(
        url: origin,
        tokenReader: tokenStore.readAccessToken,
      );
});

/// 위치 서비스(권한 + 위치 스트림). 테스트/온보딩에서 fake 로 override 가능.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// dio baseUrl(`http://host:3000/api`) → 소켓 origin(`http://host:3000`).
String _socketOrigin(String baseUrl) {
  try {
    final u = Uri.parse(baseUrl);
    if (u.hasScheme && u.host.isNotEmpty) return u.origin;
  } catch (_) {}
  return baseUrl;
}
