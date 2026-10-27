import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 당근 Seed 디자인 시스템 — Callout.
/// 스펙 참조: docs/seed-component-specs.md §8 Callout
/// (padding/gap/radius/minHeight 공통값, tone별 weak 배경+텍스트/아이콘 색)
enum SeedCalloutVariant { neutral, info, warning, danger, brand }

class SeedCallout extends StatelessWidget {
  final SeedCalloutVariant variant;
  final String title;
  final String? description;
  final IconData? icon;

  const SeedCallout({
    super.key,
    this.variant = SeedCalloutVariant.neutral,
    required this.title,
    this.description,
    this.icon,
  });

  _SeedCalloutColors get _colors {
    switch (variant) {
      case SeedCalloutVariant.neutral:
        return const _SeedCalloutColors(
          background: AppSemanticColors.backgroundSecondary,
          foreground: AppSemanticColors.textSecondary,
          titleColor: AppSemanticColors.textPrimary,
          bodyColor: AppSemanticColors.textSecondary,
          defaultIcon: Icons.info_outline,
        );
      case SeedCalloutVariant.info:
        return const _SeedCalloutColors(
          background: AppSemanticColors.statusInfoBackground,
          foreground: AppSemanticColors.statusInfoIcon,
          // 파랑은 아이콘에만 — 제목·본문까지 파랗게 칠하면 틸 팔레트에서 따로 놀고 읽기도 힘들다
          titleColor: AppSemanticColors.textPrimary,
          bodyColor: AppSemanticColors.textSecondary,
          defaultIcon: Icons.info_outline,
        );
      case SeedCalloutVariant.warning:
        return const _SeedCalloutColors(
          background: AppSemanticColors.statusWarningBackground,
          foreground: AppSemanticColors.statusWarningText,
          defaultIcon: Icons.warning_amber_outlined,
        );
      case SeedCalloutVariant.danger:
        return const _SeedCalloutColors(
          background: AppSemanticColors.statusErrorBackground,
          foreground: AppSemanticColors.statusErrorText,
          defaultIcon: Icons.error_outline,
        );
      case SeedCalloutVariant.brand:
        return const _SeedCalloutColors(
          background: AppSemanticColors.brandWeak,
          foreground: AppSemanticColors.brandPressed,
          defaultIcon: Icons.campaign_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3_5,
        vertical: AppSpacing.space3_5,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.space2_5), // r2_5
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? colors.defaultIcon, size: 16, color: colors.foreground), // x4
          const SizedBox(width: AppSpacing.space3), // gap
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(color: colors.titleColor),
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.space0_5),
                  Text(
                    description!,
                    style: AppTypography.bodySmall.copyWith(color: colors.bodyColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeedCalloutColors {
  final Color background;
  final Color foreground;
  final Color? titleColor0;
  final Color? bodyColor0;
  final IconData defaultIcon;

  const _SeedCalloutColors({
    required this.background,
    required this.foreground,
    Color? titleColor,
    Color? bodyColor,
    required this.defaultIcon,
  })  : titleColor0 = titleColor,
        bodyColor0 = bodyColor;

  Color get titleColor => titleColor0 ?? foreground;
  Color get bodyColor => bodyColor0 ?? foreground;
}
