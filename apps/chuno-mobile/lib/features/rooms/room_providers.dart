import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'room_models.dart';
import 'room_repository.dart';

/// 방 원격 저장소. 인증 API 클라이언트(apiClientProvider)를 사용한다.
/// 테스트에서는 fake 로 override 한다.
final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => HttpRoomRepository(ref.watch(apiClientProvider)),
);

/// 홈 방목록 필터(거리·제한시간 프리셋). 칩 선택 시 갱신 → roomListProvider 재조회.
final roomFiltersProvider =
    NotifierProvider<RoomFiltersController, RoomFilters>(RoomFiltersController.new);

class RoomFiltersController extends Notifier<RoomFilters> {
  @override
  RoomFilters build() => const RoomFilters();

  void setDistance(int idx) => state = state.copyWith(distanceIdx: idx);
  void setLimit(int idx) => state = state.copyWith(limitIdx: idx);
}

/// 홈에서 표시할 방목록. 활성 상태(recruiting·starting·live)만, 임박순 정렬.
/// 필터를 서버 쿼리(min/max)로 반영한다. 새로고침은 `ref.invalidate(roomListProvider)`.
final roomListProvider = FutureProvider<List<RoomModel>>((ref) {
  final filters = ref.watch(roomFiltersProvider);
  final d = filters.distance;
  final l = filters.limit;
  return ref.watch(roomRepositoryProvider).list(
        statuses: const [RoomStatus.recruiting, RoomStatus.starting, RoomStatus.live],
        minTargetDistance: d.min,
        maxTargetDistance: d.max,
        minLimitMinutes: l.min,
        maxLimitMinutes: l.max,
        sort: 'scheduledStartOn',
        order: 'ASC',
      );
});

/// 방 상세(`GET /rooms/:id`). 로비 화면에서 roomId 로 소비한다.
/// 재시도는 `ref.invalidate(roomDetailProvider(id))`.
final roomDetailProvider = FutureProvider.family<RoomModel, int>(
  (ref, id) => ref.watch(roomRepositoryProvider).retrieve(id),
);
