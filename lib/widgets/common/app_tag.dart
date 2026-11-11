import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 꼬리표의 뜻 — 색은 상태에만 쓴다(웹 DESIGN.md '색은 상태만'과 같다).
/// 분류(연차·공지 고정 등)는 [neutral]로 두고 글자로 구분한다.
enum AppTagTone { neutral, accent, success, warning, error }

/// 옅은 바탕 + 진한 글자의 작은 꼬리표. 진한 바탕 알약을 화면마다 따로 그리지 않게 한 곳에 모았다.
class AppTag extends StatelessWidget {
  final String label;
  final AppTagTone tone;
  final IconData? icon;

  const AppTag({
    super.key,
    required this.label,
    this.tone = AppTagTone.neutral,
    this.icon,
  });

  /// 꼬리표(상태 알약)의 글자 — labelStrong 13/w600(B안). 화면에서 따로 굵기를 얹지 않고 이걸 쓴다.
  static const TextStyle labelStyle = AppTypography.labelStrong;

  static ({Color background, Color foreground}) colorsOf(AppTagTone tone) {
    switch (tone) {
      case AppTagTone.neutral:
        return (
          background: AppSemanticColors.fillDefault,
          foreground: AppSemanticColors.textSecondary,
        );
      case AppTagTone.accent:
        return (
          background: AppSemanticColors.brandWeak,
          foreground: AppSemanticColors.brandWeakForeground,
        );
      case AppTagTone.success:
        return (
          background: AppSemanticColors.statusSuccessBackground,
          foreground: AppSemanticColors.statusSuccessText,
        );
      case AppTagTone.warning:
        return (
          background: AppSemanticColors.statusWarningBackground,
          foreground: AppSemanticColors.statusWarningText,
        );
      case AppTagTone.error:
        return (
          background: AppSemanticColors.statusErrorBackground,
          foreground: AppSemanticColors.statusErrorText,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsOf(tone);
    // B안(시안 .pill): 테두리 없는 옅은 알약, 높이 26 이상, 좌우 10, 13/w600
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 26),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space2_5,
            vertical: AppSpacing.space0_5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: colors.foreground),
                const SizedBox(width: 3),
              ],
              // Flexible로 감싸지 않는다 — 꼬리표는 폭 제한 없는 Row 안에도 놓인다
              Text(
                label,
                maxLines: 1,
                style: labelStyle.copyWith(color: colors.foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
