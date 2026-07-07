// S5-2 푸시 — payload 파싱 / device-token 등록·해제 계약 / 등록 생명주기(권한·토큰) /
// 딥링크 라우팅(type→화면). 실 Firebase 없이 fake 로 유닛 검증.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:chuno_mobile/core/env/env.dart';
import 'package:chuno_mobile/core/network/api_client.dart';
import 'package:chuno_mobile/core/storage/key_value_store.dart';
import 'package:chuno_mobile/features/auth/auth_providers.dart';
import 'package:chuno_mobile/features/notifications/device_token_repository.dart';
import 'package:chuno_mobile/features/notifications/push_controller.dart';
import 'package:chuno_mobile/features/notifications/push_host.dart';
import 'package:chuno_mobile/features/notifications/push_models.dart';
import 'package:chuno_mobile/features/notifications/push_router.dart';
import 'package:chuno_mobile/features/notifications/push_service.dart';
import 'package:chuno_mobile/features/scoring/scoring_models.dart';
import 'package:chuno_mobile/features/scoring/scoring_providers.dart';
import 'package:chuno_mobile/features/scoring/scoring_repository.dart';
import 'package:chuno_mobile/features/users/user_models.dart';
import 'package:chuno_mobile/features/users/user_providers.dart';
import 'package:chuno_mobile/features/users/user_repository.dart';
import 'package:chuno_mobile/screens/lobby_screen.dart';
import 'package:chuno_mobile/screens/result_screen.dart';
import 'package:chuno_mobile/theme/app_theme.dart';

/// 초기화/스트림을 제어 가능한 fake 푸시 서비스.
class FakePushService implements PushService {
  final PushInit initResult;
  final _refresh = StreamController<String>.broadcast();
  final _fg = StreamController<PushMessage>.broadcast();
  final _open = StreamController<PushMessage>.broadcast();
  PushMessage? initialMessage;
  int initCalls = 0;

  FakePushService(this.initResult);

  @override
  String get platform => 'android';
  @override
  Future<PushInit> initialize() async {
    initCalls++;
    return initResult;
  }

  @override
  Stream<PushMessage> get onForegroundMessage => _fg.stream;
  @override
  Stream<PushMessage> get onMessageOpenedApp => _open.stream;
  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;
  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  void rotate(String t) => _refresh.add(t);
  void emitForeground(PushMessage m) => _fg.add(m);
  void emitOpen(PushMessage m) => _open.add(m);
}

/// 온보딩 판정(getMe)이 네트워크 없이 완료되도록 하는 fake — userId 42 를 나로.
class _FakeUserRepository implements UserRepository {
  @override
  Future<bool> checkNickname(String nickname) async => true;
  @override
  Future<void> onboard({
    required String nickname,
    required String level,
    required List<int> legalDocumentIds,
  }) async {}
  @override
  Future<MeModel> getMe() async => MeModel(id: '42', onboardedOn: DateTime(2026));
}

/// 결과 딥링크 대상(ResultScreen) 렌더용 최소 fake.
class _FakeScoringRepository implements ScoringRepository {
  @override
  Future<RankingBoard> getRankings({required RankingScope scope}) async =>
      RankingBoard(scope: scope, items: const [], total: 0);
  @override
  Future<MyResultsPage> getMyResults({int? page, int? limit}) async =>
      const MyResultsPage(items: [], total: 0);
  @override
  Future<RaceResultSet> getRaceResult(int raceId) async =>
      RaceResultSet(raceId: raceId, results: const []);
}

/// 등록/해제 호출을 기록하는 fake 저장소.
class FakeDeviceTokenRepository implements DeviceTokenRepository {
  final registered = <({String token, String platform})>[];
  final unregistered = <String>[];

  @override
  Future<void> register({required String token, required String platform}) async =>
      registered.add((token: token, platform: platform));
  @override
  Future<void> unregister(String token) async => unregistered.add(token);
}

ProviderContainer _container(FakePushService svc, FakeDeviceTokenRepository repo) {
  final c = ProviderContainer(overrides: [
    pushServiceProvider.overrideWithValue(svc),
    deviceTokenRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  c.listen(pushControllerProvider, (_, _) {}, fireImmediately: true);
  return c;
}

void main() {
  group('PushMessage.fromData', () {
    test('type/roomId/raceId 파싱(문자열·숫자 혼용)', () {
      final m = PushMessage.fromData(
        {'type': 'RESULT_READY', 'roomId': '12', 'raceId': 34},
        title: '결과 준비',
      );
      expect(m.type, NotiType.resultReady);
      expect(m.roomId, 12);
      expect(m.raceId, 34);
      expect(m.title, '결과 준비');
      expect(m.isRoutable, isTrue);
    });

    test('알 수 없는 type → unknown, 라우팅 불가', () {
      final m = PushMessage.fromData({'type': 'SOMETHING'});
      expect(m.type, NotiType.unknown);
      expect(m.isRoutable, isFalse);
    });

    test('RACE_STARTING 은 roomId 없으면 라우팅 불가', () {
      expect(PushMessage.fromData({'type': 'RACE_STARTING'}).isRoutable, isFalse);
      expect(
          PushMessage.fromData({'type': 'RACE_STARTING', 'roomId': 1}).isRoutable,
          isTrue);
    });
  });

  group('destinationForPush (딥링크 type→화면)', () {
    test('RACE_STARTING → 방 로비(roomId)', () {
      final w = destinationForPush(
          const PushMessage(type: NotiType.raceStarting, roomId: 7));
      expect(w, isA<LobbyScreen>());
      expect((w as LobbyScreen).roomId, 7);
    });

    test('PARTICIPANT_JOINED → 방 로비(roomId)', () {
      final w = destinationForPush(
          const PushMessage(type: NotiType.participantJoined, roomId: 9));
      expect(w, isA<LobbyScreen>());
      expect((w as LobbyScreen).roomId, 9);
    });

    test('RESULT_READY → 결과 화면(raceId + 내 userId)', () {
      final w = destinationForPush(
          const PushMessage(type: NotiType.resultReady, raceId: 55),
          myUserId: 42);
      expect(w, isA<ResultScreen>());
      expect((w as ResultScreen).raceId, 55);
      expect(w.userId, 42);
    });

    test('식별자 부재/unknown → null(무라우팅)', () {
      expect(destinationForPush(const PushMessage(type: NotiType.raceStarting)),
          isNull);
      expect(destinationForPush(const PushMessage(type: NotiType.resultReady)),
          isNull);
      expect(destinationForPush(const PushMessage(type: NotiType.unknown)), isNull);
    });
  });

  group('PushController 등록 생명주기', () {
    test('권한 granted + 토큰 → 서버 등록(platform 포함)', () async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.granted, token: 'tok-1'));
      final repo = FakeDeviceTokenRepository();
      final c = _container(svc, repo);

      await c.read(pushControllerProvider.notifier).register();

      expect(repo.registered.length, 1);
      expect(repo.registered.first.token, 'tok-1');
      expect(repo.registered.first.platform, 'android');
      expect(c.read(pushControllerProvider).registeredToken, 'tok-1');
    });

    test('Firebase 미설정(available=false) → 초기화만 하고 등록 안 함(graceful)', () async {
      final svc = FakePushService(PushInit.unavailable);
      final repo = FakeDeviceTokenRepository();
      final c = _container(svc, repo);

      await c.read(pushControllerProvider.notifier).register();

      expect(c.read(pushControllerProvider).available, isFalse);
      expect(repo.registered, isEmpty);
    });

    test('권한 denied → 토큰 있어도 등록 안 함', () async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.denied, token: 'tok-x'));
      final repo = FakeDeviceTokenRepository();
      final c = _container(svc, repo);

      await c.read(pushControllerProvider.notifier).register();
      expect(repo.registered, isEmpty);
    });

    test('onTokenRefresh → 회전 토큰 재등록', () async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.granted, token: 'tok-1'));
      final repo = FakeDeviceTokenRepository();
      final c = _container(svc, repo);

      await c.read(pushControllerProvider.notifier).register();
      svc.rotate('tok-2');
      await Future<void>.delayed(Duration.zero);

      expect(repo.registered.map((e) => e.token), containsAllInOrder(['tok-1', 'tok-2']));
      expect(c.read(pushControllerProvider).registeredToken, 'tok-2');
    });

    test('register 는 멱등 — 이미 초기화면 재초기화하지 않는다', () async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.granted, token: 'tok-1'));
      final repo = FakeDeviceTokenRepository();
      final c = _container(svc, repo);

      final ctrl = c.read(pushControllerProvider.notifier);
      await ctrl.register();
      await ctrl.register();
      expect(svc.initCalls, 1);
    });

    test('unregister → 등록 토큰 서버 해제 + 상태 클리어', () async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.granted, token: 'tok-1'));
      final repo = FakeDeviceTokenRepository();
      final c = _container(svc, repo);

      final ctrl = c.read(pushControllerProvider.notifier);
      await ctrl.register();
      await ctrl.unregister();

      expect(repo.unregistered, ['tok-1']);
      expect(c.read(pushControllerProvider).registeredToken, isNull);
    });
  });

  group('HttpDeviceTokenRepository 계약', () {
    late Dio dio;
    late DioAdapter adapter;
    late HttpDeviceTokenRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'));
      adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;
      repo = HttpDeviceTokenRepository(ApiClient(dio));
    });

    test('register → POST /users/me/device-tokens {token, platform}', () async {
      adapter.onPost(
        ApiPaths.deviceTokens,
        (server) => server.reply(201, {'data': {'ok': true}}),
        data: {'token': 'abc', 'platform': 'ios'},
      );
      await repo.register(token: 'abc', platform: 'ios');
    });

    test('unregister → DELETE /users/me/device-tokens {token}', () async {
      adapter.onDelete(
        ApiPaths.deviceTokens,
        (server) => server.reply(200, {'data': {'ok': true}}),
        data: {'token': 'abc'},
      );
      await repo.unregister('abc');
    });
  });

  group('PushHost 배선(위젯)', () {
    Widget host(FakePushService svc, FakeDeviceTokenRepository repo,
        GlobalKey<NavigatorState> navKey) {
      final msgKey = GlobalKey<ScaffoldMessengerState>();
      return ProviderScope(
        overrides: [
          // 토큰 보유 → 부팅 시 authenticated 로 복원.
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore({
            'chuno.auth.accessToken': 'a1',
            'chuno.auth.refreshToken': 'r1',
          })),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          scoringRepositoryProvider.overrideWithValue(_FakeScoringRepository()),
          pushServiceProvider.overrideWithValue(svc),
          deviceTokenRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          navigatorKey: navKey,
          scaffoldMessengerKey: msgKey,
          home: PushHost(
            navigatorKey: navKey,
            messengerKey: msgKey,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      );
    }

    testWidgets('로그인 상태 부팅 → 토큰 등록 + 포그라운드 메시지 스낵바', (tester) async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.granted, token: 'tok-1'));
      final repo = FakeDeviceTokenRepository();
      await tester.pumpWidget(host(svc, repo, GlobalKey<NavigatorState>()));
      await tester.pumpAndSettle();

      // 인증 복원 후 토큰 등록됨.
      expect(repo.registered.single.token, 'tok-1');

      // 포그라운드 수신 → 스낵바 배너.
      svc.emitForeground(
          const PushMessage(type: NotiType.participantJoined, roomId: 3, title: '새 참가자'));
      await tester.pump();
      await tester.pump();
      expect(find.text('새 참가자'), findsOneWidget);
    });

    testWidgets('알림 탭(onMessageOpenedApp) → 결과 화면으로 딥링크', (tester) async {
      final svc = FakePushService(const PushInit(
          available: true, permission: PushPermission.granted, token: 'tok-1'));
      final repo = FakeDeviceTokenRepository();
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(host(svc, repo, navKey));
      await tester.pumpAndSettle();

      svc.emitOpen(const PushMessage(type: NotiType.resultReady, raceId: 55));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
    });
  });
}
