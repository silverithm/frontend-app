import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// 당근 Seed 디자인 시스템 — 화면 섹션 제목.
/// 스펙 참조: docs/seed-component-specs.md 공통 규칙 요약(타이포 스케일 t6/bold 강조 텍스트 관례)을
/// 화면 섹션 타이틀 + 옵션 액션 텍스트버튼 구성에 적용.
class SeedSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SeedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTypography.fontSizeLg, // t6
                  fontWeight: AppTypography.fontWeightBold,
                  color: AppSemanticColors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: AppTypography.fontSizeSm,
                    color: AppSemanticColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: TextStyle(
                fontSize: AppTypography.fontSizeSm,
                fontWeight: AppTypography.fontWeightSemibold,
                color: AppSemanticColors.brandDefault,
              ),
            ),
          ),
      ],
    );
  }
}
