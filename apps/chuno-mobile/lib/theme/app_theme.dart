import 'package:flutter/material.dart';

/// 추노 디자인 토큰 — "추격전"(소프트) 정체성, 메인 선셋 코랄.
class AppColors {
  static const bg = Color(0xFF0B0C10);
  static const bg2 = Color(0xFF0E1015);
  static const panel = Color(0xFF151821);
  static const panel2 = Color(0xFF1C2029);
  static const line = Color(0xFF272C36);

  static const coral = Color(0xFFFF6B4A); // primary / 나
  static const onCoral = Color(0xFF210A04); // 코랄 위 텍스트
  static const alert = Color(0xFFFF3D77); // 타겟(앞사람) / 강조
  static const done = Color(0xFF37D67A); // 완주
  static const text = Color(0xFFECEFF4);
  static const muted = Color(0xFF8A929D);

  // 참가자 색
  static const a1 = Color(0xFF9AA3AF);
  static const a2 = Color(0xFFCBB06A);
  static const a3 = Color(0xFF89A6E6);
  static const a4 = Color(0xFFD29A78);
  static const a5 = Color(0xFFAB8FCE);

  // 메인 색에서 파생되는 톤
  static Color tint([double o = 0.13]) => Color.alphaBlend(coral.withValues(alpha: o), bg);
  static Color coralA(double o) => coral.withValues(alpha: o);
  static Color alertA(double o) => alert.withValues(alpha: o);
  static Color doneA(double o) => done.withValues(alpha: o);
}

/// 코너 반경
class R {
  static const r = 18.0;
  static const sm = 13.0;
  static const pill = 22.0;
}

/// 숫자·데이터용 모노스페이스 스타일 (탭 정렬).
TextStyle numStyle({double size = 14, FontWeight w = FontWeight.w700, Color? color}) => TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: w,
      fontSize: size,
      height: 1.1,
      letterSpacing: -0.5,
      color: color ?? AppColors.text,
    );

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.coral,
      onPrimary: AppColors.onCoral,
      surface: AppColors.panel,
      error: AppColors.alert,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
