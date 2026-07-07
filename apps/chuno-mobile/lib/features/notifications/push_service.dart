/// 푸시 수신 서비스 추상화 (S5-2) — FirebaseMessaging 을 감싸 fake 테스트를 가능케 한다.
///
/// Firebase 미설정 환경(google-services.json / GoogleService-Info.plist 미배치)에서도
/// 앱이 크래시 없이 뜨도록, 초기화는 [initialize] 내부에서 try/catch 로 감싸 실패 시
/// `available=false` 로 graceful 비활성한다(백엔드 no-op 와 대칭).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_models.dart';

/// 백그라운드/종료 상태 데이터 메시지 핸들러 — 시스템 트레이가 표시를 담당하므로 no-op.
/// 별도 isolate 에서 실행되므로 top-level + vm:entry-point 여야 한다.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// 알림 권한 상태.
enum PushPermission { granted, denied, notDetermined }

/// 초기화 결과 — Firebase 사용 가능 여부 + 권한 + 토큰.
class PushInit {
  /// Firebase 초기화 성공(설정 파일 존재) 여부. false 면 푸시 기능 전체 graceful 비활성.
  final bool available;
  final PushPermission permission;
  final String? token;

  const PushInit({
    required this.available,
    this.permission = PushPermission.notDetermined,
    this.token,
  });

  static const unavailable = PushInit(available: false);
}

/// '/push' 수신 계약 — 실 FirebaseMessaging 구현과 fake 테스트 더블을 분리한다.
abstract class PushService {
  /// 플랫폼 문자열('ios'|'android') — device-token 등록 body 의 platform.
  String get platform;

  /// Firebase 초기화 + 알림 권한 요청 + FCM 토큰 획득. 실패 시 [PushInit.unavailable].
  Future<PushInit> initialize();

  /// 포그라운드 수신 메시지 스트림(인앱 배너 표시용).
  Stream<PushMessage> get onForegroundMessage;

  /// 백그라운드/종료 상태에서 알림 탭으로 앱이 열릴 때(딥링크).
  Stream<PushMessage> get onMessageOpenedApp;

  /// 종료 상태에서 알림 탭으로 콜드스타트했을 때의 최초 메시지(없으면 null).
  Future<PushMessage?> getInitialMessage();

  /// FCM 토큰 회전 스트림(회전 시 서버 재등록).
  Stream<String> get onTokenRefresh;
}

/// FirebaseMessaging 기반 실구현. Firebase 미설정이면 [initialize] 가 graceful 실패.
class FirebasePushService implements PushService {
  bool _available = false;

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<PushInit> initialize() async {
    try {
      // 이미 초기화됐으면 재사용(중복 initializeApp 방지).
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      // 백그라운드 데이터 메시지 핸들러 등록(초기화 성공 후에만).
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      _available = true;
    } catch (_) {
      // 설정 파일 미배치/플랫폼 미지원 등 — 푸시 기능만 조용히 끈다(앱은 정상 구동).
      _available = false;
      return PushInit.unavailable;
    }

    final messaging = FirebaseMessaging.instance;
    PushPermission permission = PushPermission.notDetermined;
    String? token;
    try {
      final settings = await messaging.requestPermission();
      permission = _mapAuth(settings.authorizationStatus);
      token = await messaging.getToken();
    } catch (_) {
      // 권한/토큰 획득 실패 — available 은 유지하되 토큰 없음으로 반환.
    }
    return PushInit(available: true, permission: permission, token: token);
  }

  @override
  Stream<PushMessage> get onForegroundMessage {
    if (!_available) return const Stream.empty();
    return FirebaseMessaging.onMessage.map(_toMessage);
  }

  @override
  Stream<PushMessage> get onMessageOpenedApp {
    if (!_available) return const Stream.empty();
    return FirebaseMessaging.onMessageOpenedApp.map(_toMessage);
  }

  @override
  Future<PushMessage?> getInitialMessage() async {
    if (!_available) return null;
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m == null ? null : _toMessage(m);
  }

  @override
  Stream<String> get onTokenRefresh {
    if (!_available) return const Stream.empty();
    return FirebaseMessaging.instance.onTokenRefresh;
  }

  static PushMessage _toMessage(RemoteMessage m) => PushMessage.fromData(
        m.data.map((k, v) => MapEntry(k, v as Object?)),
        title: m.notification?.title,
        body: m.notification?.body,
      );

  static PushPermission _mapAuth(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };
}
