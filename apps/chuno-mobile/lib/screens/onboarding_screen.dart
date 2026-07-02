import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/error/app_exception.dart';
import '../features/auth/auth_providers.dart';
import '../features/users/user_models.dart';
import '../features/users/user_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'terms_doc_screen.dart';

class _Step {
  final String icon;
  final String title;
  final Widget desc;
  final Widget? field;
  final String cta;
  /// true 면 표준 아이콘/제목 레이아웃 대신 동의 화면 본문을 그린다.
  final bool consent;
  const _Step(this.icon, this.title, this.desc, this.field, this.cta, {this.consent = false});
}

/// 약관 동의 항목 정의.
class _ConsentItem {
  final String key;
  final bool required;
  final String label;
  final String? doc; // 전문 뷰어 문서 키 (없으면 "보기" 미노출)
  const _ConsentItem(this.key, this.required, this.label, this.doc);
}

const List<_ConsentItem> _consentItems = [
  _ConsentItem('terms', true, '이용약관 동의', 'terms'),
  _ConsentItem('privacy', true, '개인정보 수집·이용 동의', 'privacy'),
  _ConsentItem('location', true, '위치기반서비스 이용동의', 'location'),
  _ConsentItem('marketing', false, '마케팅 정보 수신 동의', null),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _consentIndex = 2;

  int i = 0;
  int _level = 1;
  final _nick = TextEditingController(text: '러너_추노');
  final Map<String, bool> _consent = {
    for (final it in _consentItems) it.key: false,
  };

  /// 닉네임 중복확인 진행 중.
  bool _checkingNick = false;
  /// 닉네임 오류(길이/중복/네트워크) 메시지. null 이면 정상.
  String? _nickError;
  /// 마지막 "시작하기"(onboard 저장) 진행 중.
  bool _submitting = false;

  bool get _busy => _checkingNick || _submitting;

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  bool get _allRequired => _consentItems.where((it) => it.required).every((it) => _consent[it.key] == true);
  bool get _allChecked => _consentItems.every((it) => _consent[it.key] == true);

  void _toggle(String key) {
    setState(() {
      if (key == 'all') {
        final v = !_allChecked;
        for (final it in _consentItems) {
          _consent[it.key] = v;
        }
      } else {
        _consent[key] = !(_consent[key] ?? false);
      }
    });
  }

  Future<void> _openDoc(String docKey) async {
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TermsDocScreen(docKey: docKey)),
    );
    if (agreed == true) {
      setState(() => _consent[docKey] = true);
    }
  }

  List<_Step> get steps => [
        _Step('🏷️', '닉네임을 정해주세요', const Muted('경주와 랭킹에서 보여질 이름이에요.', size: 14, height: 1.6),
            _nickField(), '다음'),
        _Step('🎽', '러닝 레벨은?', const Muted('방 추천에 참고돼요.', size: 14, height: 1.6),
            _seg(['입문', '중급', '고급'], _level, (n) => setState(() => _level = n)), '다음'),
        const _Step('📋', '약관에 동의해주세요', SizedBox.shrink(), null, '동의하고 계속', consent: true),
        _Step('📍', '위치 권한이 필요해요',
            const Text.rich(
              TextSpan(style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.7), children: [
                TextSpan(text: 'GPS로 '),
                TextSpan(text: '뛴 거리만', style: TextStyle(color: AppColors.text)),
                TextSpan(text: ' 측정해 실시간 순위를 공유합니다.\n'),
                TextSpan(text: '좌표는 서버에 전송하지 않아요.', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
              ]),
              textAlign: TextAlign.center,
            ),
            const Panel(child: Muted('🔒 화면을 꺼도 측정하려면\n"항상 허용(백그라운드)"이 필요합니다.', size: 12, height: 1.8)),
            '위치 권한 허용'),
        _Step('🎯', '준비 완료!', const Muted('이제 추격전에 뛰어들 시간이에요.', size: 14, height: 1.6), null, '시작하기'),
      ];

  Widget _nickField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _nick, hint: '닉네임 (2~12자)', maxLength: 12),
        if (_nickError != null) ...[
          const SizedBox(height: 8),
          Text(
            _nickError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.alert, height: 1.4),
          ),
        ],
      ],
    );
  }

  static Widget _seg(List<String> items, int active, ValueChanged<int> onTap) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(R.sm),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var n = 0; n < items.length; n++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(n),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: n == active ? AppColors.coral : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(items[n],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: n == active ? FontWeight.w700 : FontWeight.w500,
                          color: n == active ? AppColors.onCoral : AppColors.muted)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 코랄 체크박스.
  Widget _checkBox(bool on, {bool large = false}) {
    final side = large ? 26.0 : 22.0;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? AppColors.coral : AppColors.panel2,
        borderRadius: BorderRadius.circular(large ? 8 : 7),
        border: Border.all(color: on ? AppColors.coral : AppColors.line, width: 1.5),
      ),
      child: on ? Icon(Icons.check_rounded, size: large ? 17 : 14, color: AppColors.onCoral) : null,
    );
  }

  Widget _consentBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Text('📋', style: TextStyle(fontSize: 40))),
        const SizedBox(height: 14),
        const Center(
          child: Text('약관에 동의해주세요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        const Center(child: Muted('서비스 이용을 위해 아래 약관에 동의해주세요.', size: 13, height: 1.6)),
        const SizedBox(height: 18),
        // 전체 동의
        Panel(
          onTap: () => _toggle('all'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _checkBox(_allChecked, large: true),
              const SizedBox(width: 12),
              const Text.rich(TextSpan(
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                children: [
                  TextSpan(text: '전체 동의 '),
                  TextSpan(text: '(선택 포함)', style: TextStyle(fontWeight: FontWeight.w400, color: AppColors.muted)),
                ],
              )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: AppColors.line),
        const SizedBox(height: 2),
        for (var k = 0; k < _consentItems.length; k++) _consentRow(_consentItems[k], first: k == 0),
        const SizedBox(height: 10),
        const Muted(
          '※ 위치기반서비스 이용동의(법적 동의)와 다음 단계의 기기 위치 권한 허용(OS 설정)은 서로 다른 절차예요.',
          size: 10.5,
          height: 1.6,
        ),
      ],
    );
  }

  Widget _consentRow(_ConsentItem it, {required bool first}) {
    final on = _consent[it.key] ?? false;
    return Container(
      decoration: BoxDecoration(
        border: first ? null : const Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggle(it.key),
              behavior: HitTestBehavior.opaque,
              child: _checkBox(on),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: GestureDetector(
                onTap: () => _toggle(it.key),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    it.required
                        ? Tag('필수', bg: AppColors.coralA(.16), fg: AppColors.coral)
                        : Tag('선택', bg: AppColors.panel2, fg: AppColors.muted),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(it.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.text)),
                    ),
                  ],
                ),
              ),
            ),
            if (it.doc != null)
              GestureDetector(
                onTap: () => _openDoc(it.doc!),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 0, 4),
                  child: Text('보기 ›', style: TextStyle(fontSize: 11.5, color: AppColors.coral)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    // 닉네임 단계: 길이 검증 후 중복확인을 통과해야 진행.
    if (i == 0) {
      await _checkNickThenAdvance();
      return;
    }
    if (i == _consentIndex && !_allRequired) return; // 필수 미동의 시 진행 차단
    if (i < steps.length - 1) {
      setState(() => i++);
    } else {
      await _submit();
    }
  }

  /// 닉네임 중복확인(GET /users/check-nickname) → 사용가능 시 다음 단계로.
  Future<void> _checkNickThenAdvance() async {
    final name = _nick.text.trim();
    if (name.length < 2 || name.length > 12) {
      setState(() => _nickError = '닉네임은 2~12자로 입력해주세요.');
      return;
    }
    setState(() {
      _checkingNick = true;
      _nickError = null;
    });
    try {
      final available = await ref.read(userRepositoryProvider).checkNickname(name);
      if (!mounted) return;
      if (!available) {
        setState(() {
          _checkingNick = false;
          _nickError = '이미 사용 중인 닉네임이에요.';
        });
        return;
      }
      setState(() {
        _checkingNick = false;
        i++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingNick = false;
        _nickError = _errorMessage(e);
      });
    }
  }

  /// 온보딩 저장(PUT /users/onboard) → 성공 시 세션 온보딩 완료 처리.
  /// AuthGate 가 상태 전이로 홈(MainShell)을 렌더한다.
  Future<void> _submit() async {
    setState(() => _submitting = true);
    final consents = [
      for (final it in _consentItems)
        if (_consent[it.key] == true) Consent(type: it.key, documentVersion: '1.0'),
    ];
    try {
      await ref.read(userRepositoryProvider).onboard(
            nickname: _nick.text.trim(),
            level: RunnerLevel.fromIndex(_level).wire,
            consents: consents,
          );
      if (!mounted) return;
      await ref.read(authControllerProvider.notifier).completeOnboarding();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(_errorMessage(e));
    }
  }

  String _errorMessage(Object e) =>
      e is AppException ? e.message : '문제가 발생했어요. 잠시 후 다시 시도해주세요.';

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.panel2,
      ));
  }

  void _prev() {
    FocusScope.of(context).unfocus();
    if (i > 0) {
      setState(() => i--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = steps[i];
    final ctaEnabled = !_busy && !(i == _consentIndex && !_allRequired);
    final ctaLabel = _checkingNick
        ? '확인 중…'
        : _submitting
            ? '시작하는 중…'
            : s.cta;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _prev,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(padding: EdgeInsets.all(4), child: Text('←', style: TextStyle(fontSize: 20, color: AppColors.muted))),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var n = 0; n < steps.length; n++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3.5),
                    width: n == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: n == i ? AppColors.coral : AppColors.panel2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: SingleChildScrollView(
                  key: ValueKey(i),
                  padding: EdgeInsets.symmetric(horizontal: s.consent ? 24 : 30, vertical: s.consent ? 20 : 30),
                  child: s.consent
                      ? _consentBody()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.icon, style: const TextStyle(fontSize: 58)),
                            const SizedBox(height: 18),
                            Text(s.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            s.desc,
                            if (s.field != null) ...[const SizedBox(height: 20), s.field!],
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Opacity(
                opacity: ctaEnabled ? 1 : 0.4,
                child: AppButton(ctaLabel, onTap: ctaEnabled ? _next : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
