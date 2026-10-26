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

  static ({Color background, Color foreground}) colorsOf(AppTagTone tone) {
    switch (tone) {
      case AppTagTone.neutral:
        return (
          background: AppSemanticColors.backgroundTertiary,
          foreground: AppSemanticColors.textSecondary,
        );
      case AppTagTone.accent:
        return (
          background: AppSemanticColors.brandWeak,
          foreground: AppSemanticColors.textLink,
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.foreground),
            const SizedBox(width: AppSpacing.space0_5),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: colors.foreground,
              fontWeight: AppTypography.fontWeightSemibold,
            ),
          ),
        ],
      ),
    );
  }
}
