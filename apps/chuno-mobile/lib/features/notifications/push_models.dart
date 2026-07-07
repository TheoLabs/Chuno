/// 푸시 알림(FCM) 도메인 모델 (S5-2) — core-api S5-1 NotiType/payload 계약 매핑.
///
/// 서버 payload(data)는 식별자를 문자열로 싣는다: `type`·`roomId`(있으면 `raceId`).
/// 좌표 등 민감정보는 담지 않는다(프라이버시 불변식과 무관, 알림은 식별자만).
library;

/// 알림 종류(core-api NotiType). 미매칭 문자열은 [unknown] 으로 안전 폴백.
enum NotiType {
  raceStarting, // RACE_STARTING — 곧 출발, 로비로.
  participantJoined, // PARTICIPANT_JOINED — 참가자 입장, 로비로.
  resultReady, // RESULT_READY — 결과 집계 완료, 결과 화면으로.
  unknown;

  static NotiType fromWire(String? s) => switch (s) {
        'RACE_STARTING' => raceStarting,
        'PARTICIPANT_JOINED' => participantJoined,
        'RESULT_READY' => resultReady,
        _ => unknown,
      };
}

/// 수신 알림의 표준화 모델 — FCM RemoteMessage(data + notification)를 앱 계약으로 환원.
class PushMessage {
  final NotiType type;
  final int? roomId;
  final int? raceId;
  final String? title;
  final String? body;

  const PushMessage({
    required this.type,
    this.roomId,
    this.raceId,
    this.title,
    this.body,
  });

  /// 딥링크 대상이 있는지(라우팅 가능). unknown 이거나 식별자 부재면 false.
  bool get isRoutable => switch (type) {
        NotiType.raceStarting || NotiType.participantJoined => roomId != null,
        NotiType.resultReady => raceId != null || roomId != null,
        NotiType.unknown => false,
      };

  /// 포그라운드 배너 노출용 표시 텍스트(title 우선, 없으면 종류 기본 문구).
  String get displayText {
    if (title != null && title!.isNotEmpty) return title!;
    return switch (type) {
      NotiType.raceStarting => '곧 출발해요 — 로비로 이동하세요',
      NotiType.participantJoined => '새 참가자가 입장했어요',
      NotiType.resultReady => '경주 결과가 집계됐어요',
      NotiType.unknown => '알림이 도착했어요',
    };
  }

  /// FCM data map + (선택)notification title/body 를 표준 모델로 파싱.
  factory PushMessage.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) =>
      PushMessage(
        type: NotiType.fromWire(data['type']?.toString()),
        roomId: _int(data['roomId']),
        raceId: _int(data['raceId']),
        title: title,
        body: body,
      );

  static int? _int(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
