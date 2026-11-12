import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../seed/seed_button.dart';

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
            // B안(시안 .empty-card): 옅은 틸 둥근 바탕 56 + 틸 아이콘, 제목 18/w700, 설명 14 회색
            Container(
              width: AppSpacing.space14,
              height: AppSpacing.space14,
              decoration: const BoxDecoration(
                color: AppSemanticColors.brandWeak,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 26,
                color: AppSemanticColors.brandDefault,
              ),
            ),
            const SizedBox(height: AppSpacing.space3_5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading6.copyWith(
                color: AppSemanticColors.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.space1_5),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppSemanticColors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.space5),
              SeedButton(
                label: actionLabel!,
                variant: SeedButtonVariant.neutralWeak,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
