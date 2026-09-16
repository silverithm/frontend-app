import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 공통 빈 상태 위젯 (D7): 부드러운 원 안 아이콘 + 제목 + 설명 + 선택적 액션 버튼.
///
/// 회의록/기관 자료실/회원 관리 승인 대기/고충·건의함/내 휴무/공지사항/채팅 목록
/// 등 여러 화면에서 제각각이던 빈 상태를 이 위젯으로 통일한다.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.topSpacing = AppSpacing.space16,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: topSpacing,
          bottom: AppSpacing.space8,
          left: AppSpacing.space6,
          right: AppSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppSemanticColors.backgroundSecondary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: AppSemanticColors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: AppTypography.fontWeightSemibold,
                color: AppSemanticColors.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.space1_5),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textTertiary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.space5),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppSemanticColors.textPrimary,
                  side: BorderSide(color: AppSemanticColors.borderDefault),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space5,
                    vertical: AppSpacing.space2_5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
