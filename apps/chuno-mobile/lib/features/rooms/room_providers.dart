import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'room_models.dart';
import 'room_repository.dart';

/// 방 원격 저장소. 인증 API 클라이언트(apiClientProvider)를 사용한다.
/// 테스트에서는 fake 로 override 한다.
final roomRepositoryProvider = Provider<RoomRepository>(
  (ref) => HttpRoomRepository(ref.watch(apiClientProvider)),
);

/// 홈 방목록 필터(거리·제한시간 min/max 범위). 레인지바 조작 시 갱신 → roomListProvider 재조회.
final roomFiltersProvider =
    NotifierProvider<RoomFiltersController, RoomFilters>(RoomFiltersController.new);

class RoomFiltersController extends Notifier<RoomFilters> {
  @override
  RoomFilters build() => const RoomFilters();

  /// 거리 범위 설정(km). min<=max 는 호출부/레인지바가 보장.
  void setDistance(int min, int max) =>
      state = state.copyWith(distanceMin: min, distanceMax: max);

  /// 제한 시간 범위 설정(분).
  void setLimit(int min, int max) =>
      state = state.copyWith(limitMin: min, limitMax: max);
}

/// 홈에서 표시할 방목록. 활성 상태(recruiting·starting·live)만, 임박순 정렬.
/// 필터를 서버 쿼리(min/max)로 반영한다. 전체 범위(미적용)면 null 전달 → 모든 방 노출.
/// 새로고침은 `ref.invalidate(roomListProvider)`.
final roomListProvider = FutureProvider<List<RoomModel>>((ref) {
  final filters = ref.watch(roomFiltersProvider);
  return ref.watch(roomRepositoryProvider).list(
        statuses: const [RoomStatus.recruiting, RoomStatus.starting, RoomStatus.live],
        minTargetDistance: filters.queryDistanceMin,
        maxTargetDistance: filters.queryDistanceMax,
        minLimitMinutes: filters.queryLimitMin,
        maxLimitMinutes: filters.queryLimitMax,
        sort: 'scheduledStartOn',
        order: 'ASC',
      );
});

/// 방 상세(`GET /rooms/:id`). 로비 화면에서 roomId 로 소비한다.
/// 재시도는 `ref.invalidate(roomDetailProvider(id))`.
final roomDetailProvider = FutureProvider.family<RoomModel, int>(
  (ref, id) => ref.watch(roomRepositoryProvider).retrieve(id),
);
