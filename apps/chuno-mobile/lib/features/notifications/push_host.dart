import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../auth/auth_providers.dart';
import '../users/user_providers.dart';
import 'push_controller.dart';
import 'push_models.dart';
import 'push_router.dart';

/// 앱 루트를 감싸 푸시 수신을 배선하는 호스트 (S5-2).
///
/// - 인증 상태에 연동: 로그인(authenticated) 시 토큰 등록·스트림 구독, 로그아웃 시 해제.
/// - 포그라운드 수신 → 인앱 스낵바(경량 배너).
/// - 백그라운드/종료 탭(onMessageOpenedApp) + 콜드스타트(getInitialMessage) → 딥링크 라우팅.
///
/// Firebase 미설정이면 register 가 graceful 실패해 스트림 배선을 건너뛴다(무동작).
class PushHost extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  const PushHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.messengerKey,
  });

  @override
  ConsumerState<PushHost> createState() => _PushHostState();
}

class _PushHostState extends ConsumerState<PushHost> {
  StreamSubscription<PushMessage>? _fgSub;
  StreamSubscription<PushMessage>? _openSub;
  bool _wired = false;

  @override
  void initState() {
    super.initState();
    // 앱시작 시 이미 로그인 상태면(세션 복원) 최초 프레임 후 푸시 활성화.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(authControllerProvider).isAuthenticated) _enablePush();
    });
  }

  @override
  void dispose() {
    _fgSub?.cancel();
    _openSub?.cancel();
    super.dispose();
  }

  Future<void> _enablePush() async {
    if (_wired) return;
    await ref.read(pushControllerProvider.notifier).register();
    if (!mounted || !ref.read(pushControllerProvider).available) return;
    _wired = true;

    final svc = ref.read(pushServiceProvider);
    _fgSub = svc.onForegroundMessage.listen(_showBanner);
    _openSub = svc.onMessageOpenedApp.listen(_route);

    // 종료 상태에서 알림 탭으로 콜드스타트한 최초 메시지.
    final initial = await svc.getInitialMessage();
    if (initial != null && mounted) _route(initial);
  }

  Future<void> _disablePush() async {
    await ref.read(pushControllerProvider.notifier).unregister();
    await _fgSub?.cancel();
    await _openSub?.cancel();
    _fgSub = null;
    _openSub = null;
    _wired = false;
  }

  void _showBanner(PushMessage m) {
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.notifications_active, size: 18, color: AppColors.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Text(m.displayText,
                  style: const TextStyle(fontSize: 13, color: AppColors.text)),
            ),
            if (m.isRoutable)
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  _route(m);
                },
                child: const Text('보기',
                    style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ));
  }

  void _route(PushMessage m) {
    // 내 userId(결과 딥링크의 내 행 식별) — me 캐시에서 파싱(없으면 null 폴백).
    final me = ref.read(meProvider).valueOrNull;
    final myUserId = me == null ? null : int.tryParse(me.id);
    final dest = destinationForPush(m, myUserId: myUserId);
    if (dest == null) return;
    widget.navigatorKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => dest));
  }

  @override
  Widget build(BuildContext context) {
    // 인증 상태 전이에 반응 — 로그인 시 활성화, 로그아웃 시 해제.
    ref.listen(authControllerProvider, (prev, next) {
      final was = prev?.isAuthenticated ?? false;
      if (next.isAuthenticated && !was) {
        _enablePush();
      } else if (!next.isAuthenticated && was) {
        _disablePush();
      }
    });
    return widget.child;
  }
}
