# 푸시 알림(FCM) 설정 — S5-2

앱 코드는 Firebase 미설정 환경에서도 **크래시 없이** 뜬다(`Firebase.initializeApp()` try/catch → 실패 시 푸시만 graceful 비활성). 실제 푸시 수신을 켜려면 아래 **외부 산출물(사용자 Firebase 프로젝트)** 을 배치해야 한다.

## 1. Firebase 프로젝트 산출물 배치 (필수)

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist` (Xcode 로 Runner 타깃에 추가)

두 파일은 저장소에 커밋하지 않는다(각자 Firebase 콘솔에서 발급).

## 2. Android

이미 반영됨:
- `AndroidManifest.xml`: `POST_NOTIFICATIONS` 권한(Android 13+ 런타임 권한), FCM 기본 알림 채널 meta(`chuno_default`).
- `firebase_messaging` 플러그인이 `FirebaseMessagingService` 를 매니페스트 병합으로 자동 등록.

`google-services.json` 배치 후 gradle 플러그인 적용:

```kotlin
// android/settings.gradle.kts — plugins 블록에 추가
id("com.google.gms.google-services") version "4.4.2" apply false

// android/app/build.gradle.kts — plugins 블록에 추가
id("com.google.gms.google-services")
```

미적용이어도 빌드는 되지만(런타임 graceful 비활성), 실제 수신하려면 적용 필요.

## 3. iOS

이미 반영됨(`Info.plist`): `UIBackgroundModes`에 `remote-notification`·`fetch`, `FirebaseAppDelegateProxyEnabled=true`.

Xcode 에서 추가로:
1. Runner 타깃 → Signing & Capabilities → **Push Notifications** capability 추가(= `aps-environment` entitlement 생성).
2. **Background Modes** → Remote notifications 체크.
3. Apple Developer 콘솔에서 APNs Key(.p8) 발급 → Firebase 콘솔 Cloud Messaging 에 업로드.
4. `GoogleService-Info.plist` 를 Runner 타깃에 포함.

## 4. 동작 요약(코드)

- 등록: 로그인/앱시작 시 `POST /users/me/device-tokens {token, platform}`, `onTokenRefresh` 재등록, 로그아웃 시 `DELETE`.
- 포그라운드: 인앱 스낵바(경량 배너).
- 백그라운드/종료 탭·콜드스타트: payload `type`(RACE_STARTING·PARTICIPANT_JOINED→방 로비, RESULT_READY→결과) + `roomId`/`raceId` 로 딥링크.

## 미검증(외부 의존)

실 FCM 수신·딥링크 콜드스타트·APNs 토큰 매핑은 실기기 + 위 Firebase 산출물 배치 후에만 검증 가능(현 저장소에는 미배치).
