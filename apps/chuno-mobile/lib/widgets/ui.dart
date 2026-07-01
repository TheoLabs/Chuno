import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// 카드형 패널. hud=true 면 은은한 코랄 글로우 + 좌측 액센트.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool hud;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  final double radius;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.hud = false,
    this.color,
    this.border,
    this.onTap,
    this.radius = R.r,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.panel,
        borderRadius: BorderRadius.circular(radius),
        border: border ??
            Border.all(color: hud ? AppColors.coralA(.18) : AppColors.line),
        boxShadow: [
          if (hud)
            BoxShadow(color: AppColors.coralA(.22), blurRadius: 34, spreadRadius: -18, offset: const Offset(0, 14))
          else
            BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 22, spreadRadius: -16, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: content);
    }
    return content;
  }
}

enum BtnVariant { primary, ghost, outline, alert, custom }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final double height;
  final bool expand;
  final Color? bg;
  final Color? fg;
  final double fontSize;
  const AppButton(
    this.label, {
    super.key,
    this.onTap,
    this.variant = BtnVariant.primary,
    this.height = 52,
    this.expand = true,
    this.bg,
    this.fg,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    Color background = AppColors.panel2;
    Color foreground = AppColors.text;
    Border? border;
    Gradient? gradient;
    List<BoxShadow>? shadow;
    switch (variant) {
      case BtnVariant.primary:
        gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.alphaBlend(Colors.white.withValues(alpha: .28), AppColors.coral), AppColors.coral],
        );
        foreground = AppColors.onCoral;
        shadow = [BoxShadow(color: AppColors.coralA(.42), blurRadius: 26, spreadRadius: -12, offset: const Offset(0, 10))];
        break;
      case BtnVariant.ghost:
        background = AppColors.panel2;
        border = Border.all(color: AppColors.line);
        break;
      case BtnVariant.outline:
        background = Colors.transparent;
        foreground = AppColors.coral;
        border = Border.all(color: AppColors.coralA(.6));
        break;
      case BtnVariant.alert:
        background = Colors.transparent;
        foreground = AppColors.alert;
        border = Border.all(color: AppColors.alertA(.45));
        break;
      case BtnVariant.custom:
        background = bg ?? AppColors.panel2;
        foreground = fg ?? AppColors.text;
        break;
    }
    final child = Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient,
        border: border,
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadow,
      ),
      child: Text(label,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: fontSize, color: foreground, letterSpacing: -0.1)),
    );
    final tappable = GestureDetector(
      onTap: onTap,
      behavior: onTap == null ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: tappable) : tappable;
  }
}

class PillChip extends StatelessWidget {
  final String text;
  final bool active;
  const PillChip(this.text, {super.key, this.active = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.coral : AppColors.panel2,
          borderRadius: BorderRadius.circular(R.pill),
          border: Border.all(color: active ? AppColors.coral : AppColors.line),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.onCoral : AppColors.text)),
      );
}

class Tag extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Tag(this.text, {super.key, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
}

class Avatar extends StatelessWidget {
  final String label;
  final Color color;
  final double size;
  final Color? fg;
  final bool dashed;
  const Avatar(this.label, this.color, {super.key, this.size = 36, this.fg, this.dashed = false});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: dashed ? Border.all(color: AppColors.line) : null,
        ),
        child: Text(label,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.38, color: fg ?? AppColors.onCoral)),
      );
}

/// 작은 뮤트 라벨
class Muted extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final double height;
  const Muted(this.text, {super.key, this.size = 11, this.color, this.height = 1.4});
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: size, color: color ?? AppColors.muted, height: height));
}

/// 실제 입력 가능한 텍스트 필드 (디자인 시스템에 맞춘 스타일).
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? suffixText;
  final int? maxLength;
  final bool digitsOnly;
  const AppTextField({super.key, this.controller, this.hint, this.keyboardType, this.suffixText, this.maxLength, this.digitsOnly = false});
  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(color: AppColors.line),
        ),
        alignment: Alignment.center,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              inputFormatters: digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
              cursorColor: AppColors.coral,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w400),
              ),
            ),
          ),
          if (suffixText != null) Text(suffixText!, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
        ]),
      );
}

/// 아직 구현되지 않은 액션에 가벼운 피드백을 주는 스낵바.
void comingSoon(BuildContext context, [String msg = '준비 중이에요']) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1300),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.panel2,
    ));
}

/// 탭 상단 공용 헤더. 우측에 항상 알림 벨(박스 없는 아이콘)이 있고,
/// 탭별 추가 액션은 벨 왼쪽에 붙는다.
class TabHeader extends StatelessWidget {
  final Widget title;
  final List<Widget> trailing;
  const TabHeader({super.key, required this.title, this.trailing = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            child: title,
          ),
          Row(children: [
            ...trailing,
            GestureDetector(
              onTap: () => comingSoon(context, '알림은 준비 중이에요'),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.text),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
