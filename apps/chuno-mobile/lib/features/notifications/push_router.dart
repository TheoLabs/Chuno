import 'package:flutter/material.dart';

import '../../models.dart';
import '../../screens/lobby_screen.dart';
import '../../screens/result_screen.dart';
import 'push_models.dart';

/// 딥링크 대상 화면(방 로비 진입용) 표시 폴백 방 — roomId 로 상세를 실제 로드하므로
/// 이 값은 로딩 전 잠깐만 보인다.
const _placeholderRoom = Room(
  name: '경주 방',
  targetKm: 0,
  limitMin: 0,
  cur: 0,
  max: 0,
  startInfo: '',
  status: RoomStatus.soon,
);

/// 알림 payload → 딥링크 목적지 화면 (S5-2). 라우팅 대상이 없으면 null.
///
/// - RACE_STARTING / PARTICIPANT_JOINED → 해당 방 로비([LobbyScreen], roomId 로 상세 로드)
/// - RESULT_READY → 결과 화면([ResultScreen], raceId 직접 조회 + 내 userId)
Widget? destinationForPush(PushMessage m, {int? myUserId}) {
  switch (m.type) {
    case NotiType.raceStarting:
    case NotiType.participantJoined:
      final roomId = m.roomId;
      if (roomId == null) return null;
      return LobbyScreen(room: _placeholderRoom, roomId: roomId);
    case NotiType.resultReady:
      final raceId = m.raceId;
      if (raceId == null) return null;
      return ResultScreen(raceId: raceId, userId: myUserId);
    case NotiType.unknown:
      return null;
  }
}
